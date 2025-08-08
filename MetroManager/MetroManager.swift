import SwiftUI
import Foundation

class MetroManager: ObservableObject {
    @Published var projects: [MetroProject] = []
    @Published var selectedProject: MetroProject?
    @Published var errorMessage: String? = nil
    @Published var showingErrorAlert: Bool = false
    @Published var consoleTextSize: CGFloat = 12.0
    
    private let defaultPorts = [8081, 8082, 8083, 8084, 8085]
    
    init() {
        loadProjects()
        loadSettings()
        // 중복 프로젝트 정리
        cleanupDuplicateProjects()
        // 앱 시작 시 실행 중인 Metro 프로세스 감지
        detectRunningMetroProcesses()
        // 백그라운드 실시간 감지 시작
        startBackgroundProcessMonitoring()
    }
    
    func addProject(name: String, path: String) {
        let availablePort = findAvailablePort()
        let projectType: ProjectType = isExpoProject(at: path) ? .expo : .reactNativeCLI
        let project = MetroProject(name: name, path: path, port: availablePort, projectType: projectType)
        
        // 프로젝트 타입 로깅
        print("DEBUG: 프로젝트 추가 - \(name) (\(path)) 타입: \(projectType.rawValue)")
        
        projects.append(project)
        saveProjects()
    }
    
    func editProject(project: MetroProject, newName: String, newPath: String, newPort: Int, newType: ProjectType) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].name = newName
            projects[index].path = newPath
            projects[index].port = newPort
            projects[index].projectType = newType
            saveProjects()
        }
    }
    
    func removeProject(_ project: MetroProject) {
        stopMetro(for: project)
        projects.removeAll { $0.id == project.id }
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        saveProjects()
    }
    
    func startMetro(for project: MetroProject) {
        guard !project.isRunning else { return }
        
        // 디버그: 프로젝트 정보 로깅
        project.logs.append("DEBUG: 프로젝트 타입: \(project.projectType.rawValue)")
        project.logs.append("DEBUG: 프로젝트 경로: \(project.path)")
        project.logs.append("DEBUG: 포트: \(project.port)")
        
        // 경로 유효성 검사
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: project.path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            project.status = .error
            project.logs.append("ERROR: 유효하지 않은 프로젝트 경로: \(project.path)")
            self.errorMessage = "유효하지 않은 프로젝트 경로: \(project.path)"
            self.showingErrorAlert = true
            return
        }
        
        // React Native 프로젝트 검증
        guard isValidProjectPath(path: project.path) else {
            project.status = .error
            project.logs.append("ERROR: React Native/Expo 프로젝트가 아닙니다: \(project.path)")
            self.errorMessage = "React Native 또는 Expo 프로젝트가 아닙니다."
            self.showingErrorAlert = true
            return
        }
        
        // 포트가 사용 중인지 확인하고 사용 가능한 포트로 변경
        if !isPortAvailable(project.port) {
            let newPort = findAvailablePort()
            project.logs.append("포트 \(project.port)가 사용 중이므로 포트 \(newPort)로 변경합니다.")
            project.port = newPort
        } else {
            // 포트가 사용 가능한 경우 재시도 횟수 리셋
            project.retryCount = 0
        }
        
        project.status = .starting
        project.logs.removeAll()
        
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.currentDirectoryPath = project.path
        
        // 개선된 환경 변수 설정
        var environment = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        
        if let existingPath = environment["PATH"] {
            environment["PATH"] = "\(additionalPaths.joined(separator: ":"))::\(existingPath)"
        } else {
            environment["PATH"] = additionalPaths.joined(separator: ":")
        }
        process.environment = environment
        
        // Metro를 특정 포트로 시작
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        let command: String
        if project.projectType == .expo {
            // Expo 프로젝트: CI=1 환경변수로 non-interactive 모드 설정, 포트 충돌 시 자동으로 다른 포트 사용
            command = "which npx && CI=1 npx expo start --port \(project.port) --max-workers=1"
        } else {
            // React Native CLI 프로젝트
            command = "which npx && npx react-native start --port \(project.port)"
        }
        process.arguments = ["-c", command]
        
        project.logs.append("실행 명령어: \(command)")
        project.logs.append("작업 디렉토리: \(project.path)")
        
        // 출력 모니터링 개선
        pipe.fileHandleForReading.readabilityHandler = { [weak project] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        project?.logs.append(output.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    
                    // Metro 시작 감지 개선
                    let lowerOutput = output.lowercased()
                    if lowerOutput.contains("metro") && (lowerOutput.contains("waiting") || lowerOutput.contains("ready") || lowerOutput.contains("listening")) ||
                       lowerOutput.contains("expo") && lowerOutput.contains("ready") ||
                       lowerOutput.contains("development server") || 
                       lowerOutput.contains("bundler is ready") ||
                       lowerOutput.contains("waiting on http://localhost") ||
                       lowerOutput.contains("metro is running") ||
                       lowerOutput.contains("dev server ready") {
                        project?.status = .running
                        project?.isRunning = true
                        project?.retryCount = 0 // 성공 시 재시도 횟수 리셋
                        project?.logs.append("✅ Metro가 성공적으로 시작되었습니다!")
                        
                        // 성공 시 재시도 로직 중단
                        project?.shouldRetry = false
                    }
                    
                    // 포트 사용 중 오류 감지 (무한 루프 방지)
                    if lowerOutput.contains("eaddrinuse") || 
                       (lowerOutput.contains("port") && lowerOutput.contains("use") && 
                        !lowerOutput.contains("waiting on http://localhost") && 
                        !lowerOutput.contains("metro is running")) {
                        
                        // 이미 성공했거나 재시도하지 않아야 하는 경우 무시
                        guard project?.shouldRetry == true else {
                            project?.logs.append("INFO: Metro가 이미 성공적으로 시작되었으므로 재시도하지 않습니다.")
                            return
                        }
                        
                        project?.logs.append("WARNING: 포트 \(project?.port ?? 0)가 이미 사용 중입니다.")
                        
                        // 재시도 횟수 제한
                        if project?.retryCount ?? 0 < 3 {
                            project?.retryCount = (project?.retryCount ?? 0) + 1
                            project?.logs.append("재시도 \(project?.retryCount ?? 0)/3: 다른 포트를 시도합니다.")
                            
                            // 다른 포트로 재시도
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if let project = project, project.shouldRetry {
                                    self.retryWithDifferentPort(for: project)
                                }
                            }
                        } else {
                            project?.status = .error
                            project?.shouldRetry = false
                            project?.logs.append("ERROR: 최대 재시도 횟수(3회)를 초과했습니다. 수동으로 포트를 변경해주세요.")
                        }
                    }
                    
                    // Expo 특정 오류 감지
                    if lowerOutput.contains("configerror") || lowerOutput.contains("cannot determine") || 
                       lowerOutput.contains("expo") && lowerOutput.contains("not installed") {
                        project?.status = .error
                        project?.logs.append("ERROR: 이 프로젝트는 React Native CLI 프로젝트일 수 있습니다.")
                        project?.logs.append("SUGGESTION: 프로젝트를 편집하여 'React Native CLI'로 변경해보세요.")
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak project, weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        project?.logs.append("ERROR: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                        
                        // npx 명령어 찾을 수 없는 경우
                        if output.contains("command not found") && output.contains("npx") {
                            self?.errorMessage = "npx 명령어를 찾을 수 없습니다. Node.js가 설치되어 있는지 확인하세요."
                            self?.showingErrorAlert = true
                        }
                        
                        // Expo 모듈 미설치 오류
                        if output.contains("ConfigError") && output.contains("expo") && output.contains("not installed") {
                            self?.errorMessage = "Expo 모듈이 설치되지 않았습니다. 터미널에서 'npm install expo' 명령어를 실행하세요."
                            self?.showingErrorAlert = true
                        }
                        
                        project?.status = .error
                    }
                }
            }
        }
        
        process.terminationHandler = { [weak project] processInstance in
            DispatchQueue.main.async {
                project?.isRunning = false
                if project?.status == .starting {
                    project?.status = .error
                    project?.logs.append("프로세스가 예기치 않게 종료되었습니다.")
                } else if project?.status != .error {
                    project?.status = .stopped
                }
                project?.process = nil
            }
        }
        
        do {
            try process.run()
            project.process = process
            project.logs.append("Metro 시작 중... 포트: \(project.port)")
            
            // 5초 후에도 여전히 starting 상태면 타임아웃 체크
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if project.status == .starting {
                    project.logs.append("시작 시간이 오래 걸리고 있습니다. 로그를 확인하세요.")
                }
            }
            
        } catch let error as NSError {
            project.status = .error
            project.logs.append("ERROR: Metro 시작 실패 - \(error.localizedDescription)")
            self.errorMessage = "Metro 시작 실패: \(error.localizedDescription)"
            self.showingErrorAlert = true
        } catch {
            project.status = .error
            project.logs.append("ERROR: 알 수 없는 오류로 Metro 시작 실패")
            self.errorMessage = "알 수 없는 오류로 Metro 시작 실패"
            self.showingErrorAlert = true
        }
    }
    
    func stopMetro(for project: MetroProject) {
        guard project.isRunning, let process = project.process else { return }
        
        process.terminate()
        project.isRunning = false
        project.status = .stopped
        project.process = nil
        project.logs.append("Metro 중지됨")
    }
    
    func clearLogs(for project: MetroProject) {
        project.logs.removeAll()
    }
    
    // 중복 프로젝트 정리
    func cleanupDuplicateProjects() {
        var uniqueProjects: [MetroProject] = []
        var seenPaths = Set<String>()
        var seenPorts = Set<Int>()
        
        for project in projects {
            // 경로가 중복되지 않고, 포트도 중복되지 않는 경우만 추가
            if !seenPaths.contains(project.path) && !seenPorts.contains(project.port) {
                uniqueProjects.append(project)
                seenPaths.insert(project.path)
                seenPorts.insert(project.port)
            } else {
                print("DEBUG: 중복 프로젝트 제거됨 - \(project.name) (\(project.path)) 포트: \(project.port)")
            }
        }
        
        projects = uniqueProjects
        saveProjects()
    }
    
    private func retryWithDifferentPort(for project: MetroProject) {
        // 현재 프로세스 중지
        if let process = project.process {
            process.terminate()
            project.process = nil
        }
        
        // 새로운 포트 찾기
        let newPort = findAvailablePort()
        project.port = newPort
        project.logs.append("새로운 포트 \(newPort)로 Metro를 시작합니다.")
        
        // 잠시 후 다시 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startMetro(for: project)
        }
    }
    
    private func findAvailablePort() -> Int {
        let usedPorts = Set(projects.map { $0.port })
        
        // 기본 포트 중에서 사용되지 않는 포트 찾기
        for port in defaultPorts {
            if !usedPorts.contains(port) && isPortAvailable(port) {
                return port
            }
        }
        
        // 기본 포트가 모두 사용 중이면 8086부터 찾기
        for port in 8086...8100 {
            if !usedPorts.contains(port) && isPortAvailable(port) {
                return port
            }
        }
        
        // 모든 포트가 사용 중이면 시스템에서 사용 가능한 포트 찾기
        for port in 8081...8200 {
            if !usedPorts.contains(port) && isPortAvailable(port) {
                return port
            }
        }
        
        return 8081 // 최후의 수단
    }
    
    func isPortAvailable(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock != -1 else { return false }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        close(sock)
        return result == 0
    }
    
    private func isExpoProject(at path: String) -> Bool {
        // Expo 설정 파일들 확인
        let expoConfigPath = "\(path)/app.json"
        let expoConfigPathTS = "\(path)/app.config.js"
        let expoConfigPathJS = "\(path)/app.config.ts"
        let packageJsonPath = "\(path)/package.json"
        
        // app.config.js/ts가 있으면 Expo 프로젝트로 간주
        if FileManager.default.fileExists(atPath: expoConfigPathTS) ||
           FileManager.default.fileExists(atPath: expoConfigPathJS) {
            return true
        }
        
        // app.json이 있는 경우, 내용을 확인해서 Expo 설정인지 판단
        if FileManager.default.fileExists(atPath: expoConfigPath) {
            do {
                let appJsonData = try Data(contentsOf: URL(fileURLWithPath: expoConfigPath))
                if let appJson = try JSONSerialization.jsonObject(with: appJsonData) as? [String: Any] {
                    // Expo 프로젝트의 app.json에는 보통 expo 키가 있음
                    if appJson["expo"] != nil {
                        return true
                    }
                    // 또는 sdkVersion이 있으면 Expo 프로젝트
                    if appJson["sdkVersion"] != nil {
                        return true
                    }
                    // 또는 platform이 있으면 Expo 프로젝트
                    if appJson["platform"] != nil {
                        return true
                    }
                }
            } catch {
                print("DEBUG: app.json 파싱 실패: \(error)")
            }
        }
        
        // package.json에서 expo 의존성 확인
        if FileManager.default.fileExists(atPath: packageJsonPath) {
            do {
                let packageData = try Data(contentsOf: URL(fileURLWithPath: packageJsonPath))
                if let packageJson = try JSONSerialization.jsonObject(with: packageData) as? [String: Any] {
                    // dependencies나 devDependencies에서 expo 확인
                    if let dependencies = packageJson["dependencies"] as? [String: Any] {
                        if dependencies["expo"] != nil {
                            return true
                        }
                        // expo-cli가 있으면 Expo 프로젝트일 가능성이 높음
                        if dependencies["expo-cli"] != nil {
                            return true
                        }
                    }
                    if let devDependencies = packageJson["devDependencies"] as? [String: Any] {
                        if devDependencies["expo"] != nil {
                            return true
                        }
                        if devDependencies["expo-cli"] != nil {
                            return true
                        }
                    }
                    
                    // scripts에서 expo 명령어 확인
                    if let scripts = packageJson["scripts"] as? [String: Any] {
                        for (_, script) in scripts {
                            if let scriptString = script as? String {
                                if scriptString.contains("expo") {
                                    return true
                                }
                            }
                        }
                    }
                }
            } catch {
                // JSON 파싱 실패 시 파일 기반으로만 판단
                print("DEBUG: package.json 파싱 실패: \(error)")
            }
        }
        
        return false
    }
    
    func isValidProjectPath(path: String) -> Bool {
        let packageJsonPath = "\(path)/package.json"
        guard FileManager.default.fileExists(atPath: packageJsonPath) else { return false }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: packageJsonPath))
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            if let dependencies = json?["dependencies"] as? [String: Any] {
                if dependencies["react-native"] != nil || dependencies["expo"] != nil {
                    return true
                }
            }
            
            if let devDependencies = json?["devDependencies"] as? [String: Any] {
                if devDependencies["react-native"] != nil || devDependencies["expo"] != nil {
                    return true
                }
            }
            
            // scripts에서 react-native 명령어 확인
            if let scripts = json?["scripts"] as? [String: Any] {
                for (_, script) in scripts {
                    if let scriptString = script as? String {
                        if scriptString.contains("react-native") || scriptString.contains("metro") {
                            return true
                        }
                    }
                }
            }
        } catch {
            print("Error reading package.json: \(error.localizedDescription)")
        }
        return false
    }
    
    private func saveProjects() {
        let data = projects.map { project in
            [
                "name": project.name,
                "path": project.path,
                "port": project.port,
                "projectType": project.projectType.rawValue
            ] as [String: Any]
        }
        UserDefaults.standard.set(data, forKey: "MetroProjects")
        print("DEBUG: 프로젝트 저장됨 - \(data)")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(consoleTextSize, forKey: "ConsoleTextSize")
    }
    
    private func loadSettings() {
        if let savedSize = UserDefaults.standard.object(forKey: "ConsoleTextSize") as? CGFloat {
            consoleTextSize = savedSize
        }
    }
    
    private func loadProjects() {
        guard let data = UserDefaults.standard.array(forKey: "MetroProjects") as? [[String: Any]] else { return }
        
        projects = data.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let path = dict["path"] as? String,
                  let port = dict["port"] as? Int else { return nil }
            
            // 기존 프로젝트 호환성: projectType이 없으면 자동 감지
            let projectType: ProjectType
            if let projectTypeString = dict["projectType"] as? String,
               let type = ProjectType(rawValue: projectTypeString) {
                projectType = type
            } else {
                // 기존 프로젝트: 자동 감지
                projectType = isExpoProject(at: path) ? .expo : .reactNativeCLI
            }
            
            return MetroProject(name: name, path: path, port: port, projectType: projectType)
        }
    }
    
    private func getShellPath() -> String? {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "echo $PATH"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return path
            }
        } catch {
            print("Error getting shell path: \(error)")
        }
        return nil
    }
    
    // 실행 중인 Metro 프로세스 감지
    func detectRunningMetroProcesses() {
        detectRunningMetroProcesses(showUI: true)
    }
    
    // 죽은 외부 프로세스 수동 정리
    func cleanupDeadProcesses() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            var projectsToRemove: [MetroProject] = []
            var cleanupCount = 0
            
            for project in self.projects {
                if project.isExternalProcess {
                    let isStillRunning = self.isExternalProcessStillRunning(project)
                    
                    if !isStillRunning {
                        projectsToRemove.append(project)
                        cleanupCount += 1
                        NSLog("DEBUG: 수동 정리 대상 - \(project.name) (PID: \(project.externalProcessId ?? 0))")
                    }
                }
            }
            
            DispatchQueue.main.async {
                if !projectsToRemove.isEmpty {
                    NSLog("DEBUG: \(cleanupCount)개의 죽은 외부 프로세스 수동 정리 중...")
                    
                    for deadProject in projectsToRemove {
                        if let index = self.projects.firstIndex(where: { $0.id == deadProject.id }) {
                            self.projects.remove(at: index)
                            NSLog("DEBUG: 수동 제거됨 - \(deadProject.name)")
                        }
                    }
                    
                    self.saveProjects()
                    
                    // 사용자에게 결과 알림
                    self.errorMessage = "\(cleanupCount)개의 죽은 외부 프로세스가 정리되었습니다."
                    self.showingErrorAlert = true
                } else {
                    // 정리할 프로세스가 없음
                    self.errorMessage = "정리할 죽은 외부 프로세스가 없습니다."
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    // showUI 플래그로 UI 알림 제어
    private func detectRunningMetroProcesses(showUI: Bool) {
        NSLog("DEBUG: Metro 프로세스 감지 시작...")
        
        // UI 피드백은 수동 감지 시에만 표시
        if showUI {
            DispatchQueue.main.async {
                self.errorMessage = "프로세스 및 포트 스캔 중..."
                self.showingErrorAlert = true
            }
        }
        
        // 1. 포트 기반 감지 (더 정확함)
        detectAllActiveServers(showUI: showUI)
        
        // 2. 프로세스 기반 감지 (Metro 관련만)
        detectMetroProcessesByName()
    }
    
    // 모든 활성 서버 감지 (8080-8100 포트 범위)
    private func detectAllActiveServers(showUI: Bool = true) {
        NSLog("DEBUG: 전체 포트 스캔 시작 (8080-8100)...")
        
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i", ":8080-8100", "-P", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                NSLog("DEBUG: lsof 출력:")
                NSLog("%@", output)
                parsePortUsageData(output, showUI: showUI)
            }
        } catch {
            NSLog("DEBUG: lsof 명령어 실행 오류: \(error)")
        }
    }
    
    // Metro 관련 프로세스만 검색 (메인 Node 프로세스만)
    private func detectMetroProcessesByName() {
        NSLog("DEBUG: Metro 관련 프로세스 검색...")
        
        let task = Process()
        task.launchPath = "/bin/bash"
        // 실제 Metro를 실행하는 node 프로세스만 필터링 (bash, npm 제외)
        task.arguments = ["-c", "ps aux | grep 'node.*\\(expo start\\|react-native start\\|metro\\)' | grep -v grep | grep -v MetroManager"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                NSLog("DEBUG: Metro 프로세스 출력:")
                NSLog("%@", output)
                parseMetroProcesses(output)
                
                // 결과를 UI에 알림 (detectPortUsage에서 한 번만 표시)
                DispatchQueue.main.async {
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    let metroServerCount = lines.count
                    NSLog("DEBUG: Metro 프로세스 감지 완료 - \(metroServerCount)개")
                }
            }
        } catch {
            NSLog("Error detecting Metro processes: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "프로세스 감지 오류: \(error.localizedDescription)"
                self.showingErrorAlert = true
            }
        }
    }
    
    // lsof 출력 파싱하여 포트 사용 현황 분석
    private func parsePortUsageData(_ output: String, showUI: Bool = true) {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        NSLog("DEBUG: parsePortUsageData - 총 \(lines.count)개 라인 처리 중...")
        
        var detectedServers: [(port: Int, command: String, pid: Int)] = []
        
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // 헤더 라인 건너뛰기
            
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            NSLog("DEBUG: 라인 \(index): \(line)")
            NSLog("DEBUG: 컴포넌트 수: \(components.count), 마지막 컴포넌트: \(components.last ?? "없음")")
            
            if components.count >= 10 {
                let command = components[0]
                let pidString = components[1]
                let nameComponent = components[8] // TCP *:8080 (LISTEN) 형태 - 9번째 컬럼 (0부터 시작)
                
                if let pid = Int(pidString),
                   components.count >= 10 && components[9].contains("LISTEN") {
                    
                    var port: Int = 0
                    
                    // "*:포트" 패턴에서 포트 추출
                    if let colonIndex = nameComponent.firstIndex(of: ":") {
                        let portString = String(nameComponent[nameComponent.index(after: colonIndex)...])
                        
                        // 포트 번호 추출 (숫자 또는 서비스 이름)
                        switch portString {
                        case "8080", "http-alt":
                            port = 8080
                        default:
                            port = Int(portString) ?? 0
                        }
                    }
                    
                    // 8080-8100 범위의 포트만 감지
                    if port >= 8080 && port <= 8100 {
                        detectedServers.append((port: port, command: command, pid: pid))
                        NSLog("DEBUG: 포트 \(port)에서 \(command) (PID: \(pid)) 감지됨")
                    }
                }
            }
        }
        
        // 감지된 서버들을 프로젝트로 추가
        for server in detectedServers {
            let isAlreadyAdded = projects.contains { $0.port == server.port }
            
            if !isAlreadyAdded {
                // PID로 실제 프로젝트 정보 가져오기
                let projectInfo = getProjectInfoFromPID(server.pid)
                
                let projectName: String
                let projectPath: String
                let projectType: ProjectType
                let isMetro: Bool
                
                if let info = projectInfo {
                    projectName = info.name
                    projectPath = info.path
                    projectType = info.type
                    isMetro = true
                } else {
                    // 기본값 (프로젝트 정보를 찾을 수 없는 경우)
                    if server.command.contains("node") {
                        if server.port >= 8081 && server.port <= 8096 {
                            projectName = "Metro Server (포트 \(server.port))"
                            projectType = .reactNativeCLI
                            isMetro = true
                        } else {
                            projectName = "Node.js Server (포트 \(server.port))"
                            projectType = .reactNativeCLI
                            isMetro = false
                        }
                    } else {
                        projectName = "\(server.command) Server (포트 \(server.port))"
                        projectType = .reactNativeCLI
                        isMetro = false
                    }
                    projectPath = "/unknown"
                }
                
                let project = MetroProject(
                    name: projectName,
                    path: projectPath,
                    port: server.port,
                    projectType: projectType
                )
                project.isRunning = true
                project.status = .running
                project.isExternalProcess = true
                project.externalProcessId = server.pid
                project.logs.append("포트 \(server.port)에서 실행 중인 \(server.command) 서버가 감지되었습니다.")
                project.logs.append("프로세스 ID: \(server.pid)")
                project.logs.append(isMetro ? "Metro 서버로 추정됨" : "일반 서버 - 포트 충돌 방지용으로 추가됨")
                
                projects.append(project)
                NSLog("DEBUG: \(projectName) 프로젝트 추가됨 (PID: \(server.pid))")
            } else {
                NSLog("DEBUG: 포트 \(server.port) - 이미 존재하는 프로젝트")
            }
        }
        
        // 최종 결과를 UI에 표시 (수동 감지 시에만)
        DispatchQueue.main.async {
            let metroCount = detectedServers.filter { $0.port >= 8081 && $0.port <= 8096 }.count
            let otherCount = detectedServers.filter { $0.port < 8081 || $0.port > 8096 }.count
            
            if showUI {
                // 디버그 정보 포함
                let debugInfo = "라인수: \(lines.count), 감지된서버: \(detectedServers.count), 포트들: \(detectedServers.map { $0.port })"
                self.errorMessage = "감지 완료! Metro 서버 \(metroCount)개 + 기타 서버 \(otherCount)개 발견\n\n디버그: \(debugInfo)"
                self.showingErrorAlert = true
            }
            
            if !self.projects.isEmpty {
                self.saveProjects()
            }
        }
    }
    
    private func detectMetroServersByPort() {
        let metroPorts = [8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089, 8090, 8091, 8092, 8093, 8094, 8095, 8096]
        NSLog("DEBUG: 포트 스캔 시작...")
        
        var foundPorts: [Int] = []
        
        for port in metroPorts {
            if isMetroServerRunning(on: port) {
                foundPorts.append(port)
                NSLog("DEBUG: 포트 \(port)에서 Metro 서버 감지됨")
                
                // 이미 추가된 프로젝트인지 확인
                let isAlreadyAdded = projects.contains { $0.port == port }
                
                if !isAlreadyAdded {
                    let projectName = "Metro Server (포트 \(port))"
                    let project = MetroProject(
                        name: projectName,
                        path: "/unknown", // 경로는 알 수 없음
                        port: port,
                        projectType: .reactNativeCLI
                    )
                    project.isRunning = true
                    project.status = .running
                    project.isExternalProcess = true
                    project.logs.append("포트 \(port)에서 실행 중인 Metro 서버가 감지되었습니다.")
                    project.logs.append("외부 프로세스 - 경로 정보 없음")
                    
                    projects.append(project)
                    NSLog("DEBUG: 포트 \(port)에서 새 Metro 서버 프로젝트 추가됨")
                } else {
                    NSLog("DEBUG: 포트 \(port) - 이미 존재하는 프로젝트")
                }
            }
        }
        
        NSLog("DEBUG: 포트 스캔 완료 - 총 \(foundPorts.count)개 포트에서 Metro 발견: \(foundPorts)")
        
        if !projects.isEmpty {
            DispatchQueue.main.async {
                self.saveProjects()
            }
        }
    }
    
    private func isMetroServerRunning(on port: Int) -> Bool {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "curl -s http://localhost:\(port)/status || curl -s http://localhost:\(port)/"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let response = String(data: data, encoding: .utf8) {
                // Metro 서버 응답 확인
                return !response.isEmpty && (response.contains("Metro") || response.contains("React Native") || response.contains("expo"))
            }
        } catch {
            // 연결 실패는 서버가 실행되지 않음을 의미
        }
        return false
    }
    
    private func parseMetroProcesses(_ output: String) {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        NSLog("DEBUG: parseMetroProcesses - 총 \(lines.count)개 라인 처리 중...")
        
        var parsedCount = 0
        for (index, line) in lines.enumerated() {
            NSLog("DEBUG: 라인 \(index + 1): \(line)")
            if let projectInfo = extractProjectInfo(from: line) {
                parsedCount += 1
                NSLog("DEBUG: 프로젝트 정보 추출 성공 \(parsedCount) - \(projectInfo.name) (\(projectInfo.path)) 포트: \(projectInfo.port)")
                // 이미 추가된 프로젝트인지 확인 (더 정확한 중복 체크)
                let isAlreadyAdded = projects.contains { project in
                    // 같은 경로이거나 같은 이름과 포트인 경우 중복으로 간주
                    project.path == projectInfo.path || 
                    (project.name == projectInfo.name && project.port == projectInfo.port) ||
                    // 같은 포트를 사용하는 다른 프로젝트가 있는 경우
                    project.port == projectInfo.port
                }
                
                if !isAlreadyAdded {
                    let project = MetroProject(
                        name: projectInfo.name,
                        path: projectInfo.path,
                        port: projectInfo.port,
                        projectType: projectInfo.projectType
                    )
                    project.isRunning = true
                    project.status = .running
                    project.isExternalProcess = true
                    project.externalProcessId = projectInfo.pid
                    project.logs.append("외부에서 실행 중인 Metro 프로세스가 감지되었습니다.")
                    if let pid = projectInfo.pid {
                        project.logs.append("프로세스 ID: \(pid)")
                    }
                    
                    projects.append(project)
                    NSLog("DEBUG: 외부 Metro 프로세스 추가됨 - \(projectInfo.name) (\(projectInfo.path)) 포트: \(projectInfo.port) PID: \(projectInfo.pid ?? -1)")
                } else {
                    NSLog("DEBUG: 중복 프로젝트 무시됨 - \(projectInfo.name) (\(projectInfo.path)) 포트: \(projectInfo.port)")
                }
            } else {
                NSLog("DEBUG: 라인에서 프로젝트 정보 추출 실패 - \(line)")
            }
        }
        
        NSLog("DEBUG: parseMetroProcesses 완료 - 총 \(parsedCount)개 프로젝트 정보 추출됨, 현재 프로젝트 수: \(projects.count)")
        
        if !projects.isEmpty {
            DispatchQueue.main.async {
                self.saveProjects()
            }
        }
    }
    
    private func extractProjectInfo(from processLine: String) -> (name: String, path: String, port: Int, projectType: ProjectType, pid: Int?)? {
        // Metro 프로세스 라인에서 프로젝트 정보 추출
        let components = processLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 2 else { return nil }
        
        // PID 추출 (ps aux 출력의 두 번째 컬럼)
        var pid: Int?
        if components.count > 1, let pidNumber = Int(components[1]) {
            pid = pidNumber
        }
        
        // 프로젝트 경로 찾기
        var projectPath: String?
        var port: Int = 8081
        var projectType: ProjectType = .reactNativeCLI
        
        for component in components {
            if component.contains("/Users/") && (component.contains("Projects") || component.contains("projects")) {
                // node_modules 경로는 제외
                if !component.contains("node_modules") {
                    projectPath = component
                    break
                }
            }
        }
        
        guard let path = projectPath else { return nil }
        
        // 포트 번호 찾기
        for component in components {
            if component.contains("--port") {
                if let portIndex = components.firstIndex(of: component),
                   portIndex + 1 < components.count,
                   let portNumber = Int(components[portIndex + 1]) {
                    port = portNumber
                }
                break
            }
        }
        
        // 프로젝트 타입 감지 (더 정확한 감지)
        if processLine.contains("expo") && !processLine.contains("react-native") {
            projectType = .expo
        } else if processLine.contains("react-native") {
            projectType = .reactNativeCLI
        } else {
            // 경로 기반으로 재확인
            projectType = isExpoProject(at: path) ? .expo : .reactNativeCLI
        }
        
        // 프로젝트 이름 추출 (경로의 마지막 부분)
        let projectName = URL(fileURLWithPath: path).lastPathComponent
        
        return (name: projectName, path: path, port: port, projectType: projectType, pid: pid)
    }
    
    // MARK: - 백그라운드 프로세스 모니터링
    private var backgroundMonitoringTimer: Timer?
    
    private func startBackgroundProcessMonitoring() {
        // 성능 최적화: 간격을 30초로 늘려서 시스템 부하 최소화
        backgroundMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateProcessStatuses()
            self?.detectNewExternalProcesses()
        }
        NSLog("DEBUG: 백그라운드 모니터링 시작 (30초 간격)")
    }
    
    private func stopBackgroundProcessMonitoring() {
        backgroundMonitoringTimer?.invalidate()
        backgroundMonitoringTimer = nil
    }
    
    deinit {
        stopBackgroundProcessMonitoring()
    }
    
    // MARK: - 프로세스 상태 실시간 동기화
    private func updateProcessStatuses() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // 성능 최적화: 외부 프로세스가 없으면 바로 리턴
            let externalProjects = self.projects.filter { $0.isExternalProcess }
            guard !externalProjects.isEmpty else {
                NSLog("DEBUG: 외부 프로세스가 없어서 상태 확인 생략")
                return
            }
            
            var projectsToRemove: [MetroProject] = []
            
            for project in externalProjects {
                let isStillRunning = self.isExternalProcessStillRunning(project)
                
                DispatchQueue.main.async {
                    if !isStillRunning && project.status == .running {
                        project.status = .stopped
                        project.isRunning = false
                        project.logs.append("외부 프로세스가 종료되었습니다.")
                        NSLog("DEBUG: 외부 프로세스 종료 감지됨 - \(project.name)")
                        
                        // 죽은 외부 프로세스는 자동 제거 대상으로 마킹
                        projectsToRemove.append(project)
                    }
                    project.lastStatusCheck = Date()
                }
            }
            
            // 죽은 외부 프로세스들을 프로젝트 목록에서 제거
            if !projectsToRemove.isEmpty {
                DispatchQueue.main.async {
                    NSLog("DEBUG: \(projectsToRemove.count)개의 죽은 외부 프로세스 제거 중...")
                    for deadProject in projectsToRemove {
                        if let index = self.projects.firstIndex(where: { $0.id == deadProject.id }) {
                            self.projects.remove(at: index)
                            NSLog("DEBUG: 제거됨 - \(deadProject.name) (PID: \(deadProject.externalProcessId ?? 0))")
                        }
                    }
                    self.saveProjects()
                }
            }
        }
    }
    
    private func detectNewExternalProcesses() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.detectRunningMetroProcesses(showUI: false)
        }
    }
    
    private func isExternalProcessStillRunning(_ project: MetroProject) -> Bool {
        // PID로 프로세스 확인
        if let pid = project.externalProcessId {
            return isProcessRunning(pid: pid)
        }
        
        // 포트로 확인
        return isMetroServerRunning(on: project.port)
    }
    
    private func isProcessRunning(pid: Int) -> Bool {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -p \(pid) -o pid= | wc -l"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return count > 0
            }
        } catch {
            print("Error checking process: \(error)")
        }
        
        return false
    }
    
    // MARK: - 외부 프로세스 제어
    func stopExternalMetroProcess(for project: MetroProject) {
        guard project.isExternalProcess else {
            print("ERROR: 이 프로젝트는 외부 프로세스가 아닙니다.")
            return
        }
        
        var stopped = false
        
        // PID로 프로세스 종료 시도
        if let pid = project.externalProcessId {
            stopped = killProcess(pid: pid, projectName: project.name)
        }
        
        // PID로 종료되지 않았다면 포트 기반으로 프로세스 찾아서 종료
        if !stopped {
            stopped = killMetroProcessByPort(port: project.port, projectName: project.name)
        }
        
        if stopped {
            DispatchQueue.main.async {
                project.status = .stopped
                project.isRunning = false
                project.logs.append("외부 Metro 프로세스가 성공적으로 종료되었습니다.")
                print("DEBUG: 외부 Metro 프로세스 종료됨 - \(project.name)")
            }
        } else {
            DispatchQueue.main.async {
                project.logs.append("외부 Metro 프로세스 종료에 실패했습니다.")
                self.errorMessage = "Metro 프로세스 종료에 실패했습니다."
                self.showingErrorAlert = true
            }
        }
    }
    
    private func killProcess(pid: Int, projectName: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-TERM", "\(pid)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // 프로세스가 실제로 종료되었는지 확인
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !self.isProcessRunning(pid: pid) {
                    print("DEBUG: PID \(pid)로 \(projectName) 프로세스 종료 성공")
                } else {
                    // SIGTERM으로 안되면 SIGKILL 시도
                    let forceKillTask = Process()
                    forceKillTask.launchPath = "/bin/kill"
                    forceKillTask.arguments = ["-KILL", "\(pid)"]
                    try? forceKillTask.run()
                    print("DEBUG: PID \(pid)로 \(projectName) 프로세스 강제 종료 시도")
                }
            }
            
            return true
        } catch {
            print("ERROR: PID \(pid) 프로세스 종료 실패 - \(error)")
            return false
        }
    }
    
    private func killMetroProcessByPort(port: Int, projectName: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "lsof -ti tcp:\(port) | xargs kill -TERM"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // 프로세스가 실제로 종료되었는지 확인
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !self.isMetroServerRunning(on: port) {
                    print("DEBUG: 포트 \(port)로 \(projectName) 프로세스 종료 성공")
                } else {
                    // SIGTERM으로 안되면 SIGKILL 시도
                    let forceKillTask = Process()
                    forceKillTask.launchPath = "/bin/bash"
                    forceKillTask.arguments = ["-c", "lsof -ti tcp:\(port) | xargs kill -KILL"]
                    try? forceKillTask.run()
                    print("DEBUG: 포트 \(port)로 \(projectName) 프로세스 강제 종료 시도")
                }
            }
            
            return true
        } catch {
            print("ERROR: 포트 \(port) 프로세스 종료 실패 - \(error)")
            return false
        }
    }
    
    // MARK: - 외부 Metro 로그 가져오기
    func fetchExternalMetroLogs(for project: MetroProject) {
        guard project.isExternalProcess else { return }
        
        // Metro 서버의 로그 엔드포인트에 요청
        guard let url = URL(string: "http://localhost:\(project.port)/logs") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak project] data, response, error in
            if let data = data, let logString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    project?.logs.append("=== 외부 Metro 로그 ===")
                    project?.logs.append(logString)
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    project?.logs.append("외부 Metro 로그 가져오기 실패: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // PID로 프로젝트 정보 가져오기
    private func getProjectInfoFromPID(_ pid: Int) -> (name: String, path: String, type: ProjectType)? {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", String(pid), "-o", "command="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let command = output.trimmingCharacters(in: .whitespacesAndNewlines)
                NSLog("DEBUG: PID \(pid) 명령어: \(command)")
                
                // 명령어에서 프로젝트 경로 추출
                if let projectPath = extractProjectPathFromCommand(command) {
                    let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                    let projectType = determineProjectType(projectPath)
                    
                    NSLog("DEBUG: 추출된 프로젝트 - 이름: \(projectName), 경로: \(projectPath), 타입: \(projectType)")
                    return (name: projectName, path: projectPath, type: projectType)
                }
            }
        } catch {
            NSLog("DEBUG: PID \(pid) 정보 가져오기 오류: \(error)")
        }
        
        return nil
    }
    
    // 명령어에서 프로젝트 경로 추출
    private func extractProjectPathFromCommand(_ command: String) -> String? {
        // 예: "node /Users/ethanchoi/Projects/Posty_new/node_modules/.bin/react-native start --port 8087"
        
        // node_modules/.bin/ 패턴 찾기
        if let range = command.range(of: "/node_modules/.bin/") {
            let pathBeforeNodeModules = String(command[..<range.lowerBound])
            
            // 마지막 공백 이후부터 node_modules 직전까지가 프로젝트 경로
            if let lastSpaceIndex = pathBeforeNodeModules.lastIndex(of: " ") {
                let projectPath = String(pathBeforeNodeModules[pathBeforeNodeModules.index(after: lastSpaceIndex)...])
                return projectPath
            } else {
                // 공백이 없다면 전체가 경로일 수 있음
                return pathBeforeNodeModules
            }
        }
        
        // expo start 패턴도 확인
        if command.contains("expo start") {
            // 작업 디렉토리를 확인하는 다른 방법 시도
            let pwdTask = Process()
            pwdTask.launchPath = "/usr/bin/lsof"
            pwdTask.arguments = ["-a", "-p", String(extractPIDFromCommand(command) ?? 0), "-d", "cwd", "-F", "n"]
            
            let pwdPipe = Pipe()
            pwdTask.standardOutput = pwdPipe
            
            do {
                try pwdTask.run()
                let pwdData = pwdPipe.fileHandleForReading.readDataToEndOfFile()
                if let pwdOutput = String(data: pwdData, encoding: .utf8) {
                    // lsof -F n 출력에서 디렉토리 경로 추출
                    let lines = pwdOutput.components(separatedBy: .newlines)
                    for line in lines {
                        if line.hasPrefix("n") {
                            let path = String(line.dropFirst())
                            return path
                        }
                    }
                }
            } catch {
                NSLog("DEBUG: 작업 디렉토리 확인 오류: \(error)")
            }
        }
        
        return nil
    }
    
    // 명령어에서 PID 추출 (필요한 경우)
    private func extractPIDFromCommand(_ command: String) -> Int? {
        // 현재 컨텍스트에서는 이미 PID를 알고 있으므로 사용하지 않음
        return nil
    }
    
    // 프로젝트 타입 결정
    private func determineProjectType(_ projectPath: String) -> ProjectType {
        let fileManager = FileManager.default
        
        // expo 관련 파일 확인
        let expoConfigPaths = [
            "\(projectPath)/app.json",
            "\(projectPath)/app.config.js",
            "\(projectPath)/expo.json"
        ]
        
        for path in expoConfigPaths {
            if fileManager.fileExists(atPath: path) {
                // app.json인 경우 내용 확인
                if path.hasSuffix("app.json") {
                    if let data = fileManager.contents(atPath: path),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if json["expo"] != nil {
                            return .expo
                        }
                    }
                } else {
                    // expo.json이나 app.config.js인 경우 Expo 프로젝트
                    return .expo
                }
            }
        }
        
        // React Native CLI 프로젝트 확인
        let cliConfigPaths = [
            "\(projectPath)/react-native.config.js",
            "\(projectPath)/metro.config.js",
            "\(projectPath)/android/build.gradle"
        ]
        
        for path in cliConfigPaths {
            if fileManager.fileExists(atPath: path) {
                return .reactNativeCLI
            }
        }
        
        // package.json 확인
        let packageJsonPath = "\(projectPath)/package.json"
        if fileManager.fileExists(atPath: packageJsonPath) {
            if let data = fileManager.contents(atPath: packageJsonPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dependencies = json["dependencies"] as? [String: Any] {
                if dependencies["expo"] != nil {
                    return .expo
                } else if dependencies["react-native"] != nil {
                    return .reactNativeCLI
                }
            }
        }
        
        // 기본값
        return .reactNativeCLI
    }
}