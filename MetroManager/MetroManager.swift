import SwiftUI
import Foundation
import os

// MARK: - 콘솔 색상 출력을 위한 확장
extension String {
    // ANSI 색상 코드
    enum ANSIColors: String {
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case white = "\u{001B}[37m"
        case reset = "\u{001B}[0m"
    }
    
    func colored(_ color: ANSIColors) -> String {
        return color.rawValue + self + ANSIColors.reset.rawValue
    }
}

// MARK: - 로깅 유틸리티
struct Logger {
    private static let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "MetroManager", category: "MetroManager")
    
    // 컬러 지원 여부 확인
    private static var supportsColor: Bool {
        // 터미널 환경에서 컬러 지원 확인
        return ProcessInfo.processInfo.environment["TERM"] != nil || 
               isatty(STDERR_FILENO) != 0
    }
    
    // 일반 디버그 로그 (기본 색상)
    static func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        let debugMessage = "DEBUG: \(message)"
        // stdout과 stderr 둘 다에 출력하여 컬러 표시 향상
        fputs(debugMessage + "\n", stdout)
        fflush(stdout)
        logger.debug("\(message)")
        #endif
    }
    
    // 에러 로그 (빨간색)
    static func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let errorMessage = "🔴 ERROR: \(message)"
        
        // stderr에 출력 (에러는 항상 표시)
        fputs(errorMessage + "\n", stderr)
        fflush(stderr)
        
        // OS 로그에는 에러 레벨로 기록
        logger.error("\(message)")
    }
    
    // 경고 로그 (노란색)
    static func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let warningMessage = "🟡 WARNING: \(message)"
        
        // stdout에 출력
        fputs(warningMessage + "\n", stdout)
        fflush(stdout)
        
        logger.warning("\(message)")
    }
    
    // 성공 로그 (초록색)
    static func success(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let successMessage = "🟢 SUCCESS: \(message)"
        
        // stdout에 출력
        fputs(successMessage + "\n", stdout)
        fflush(stdout)
        
        logger.info("\(message)")
    }
    
    // 정보 로그 (파란색)
    static func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let infoMessage = "🔵 INFO: \(message)"
        
        // stdout에 출력
        fputs(infoMessage + "\n", stdout)
        fflush(stdout)
        
        logger.info("\(message)")
    }
}

class MetroManager: ObservableObject {
    @Published var projects: [MetroProject] = []
    @Published var selectedProject: MetroProject?
    @Published var errorMessage: String? = nil
    @Published var showingErrorAlert: Bool = false
    // 옵션
    @Published var autoAddExternalProcesses: Bool = true
    @Published var hideDuplicatePorts: Bool = true
    // 콘솔 글씨 크기 설정 제거: 기본 시스템 단축키 사용
    // 외부 로그 스트림 작업 저장 (실험적)
    private var externalLogTasks: [UUID: Process] = [:]
    
    private let defaultPorts = [8081, 8082, 8083, 8084, 8085]
    // 프로젝트 타입 강제 지정용 체크 파일명
    private let projectTypeMarkerFilename = ".metrotype"
    
    init() {
        loadProjects()
        loadOptions()
        // 중복 프로젝트 정리
        cleanupDuplicateProjects()
        // 앱 시작 시 실행 중인 Metro 프로세스 감지
        detectRunningMetroProcesses()
        // 백그라운드 실시간 감지 시작
        startBackgroundProcessMonitoring()
    }
    
    func addProject(name: String, path: String) {
        // 사용자 설정 우선 확인
        let projectType: ProjectType
        if let userProjectType = getUserProjectType(path: path) {
            projectType = userProjectType
            Logger.debug("사용자 설정 프로젝트 타입 사용: \(name) -> \(projectType.rawValue)")
        } else {
            projectType = isExpoProject(at: path) ? .expo : .reactNativeCLI
            Logger.debug("자동 감지 프로젝트 타입: \(name) -> \(projectType.rawValue)")
        }
        
        // 기본 포트 8081로 시작 (자동 포트 할당 제거)
        let project = MetroProject(name: name, path: path, port: 8081, projectType: projectType)
        
        // 프로젝트 타입 로깅
        Logger.debug("프로젝트 추가 - \(name) (\(path)) 타입: \(projectType.rawValue)")
        
        projects.append(project)
        // 타입 강제 체크 파일 생성
        writeProjectTypeMarker(at: path, type: projectType)
        saveProjects()
    }
    
    func editProject(project: MetroProject, newName: String, newPath: String, newPort: Int, newType: ProjectType) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].name = newName
            projects[index].path = newPath
            projects[index].port = newPort
            projects[index].projectType = newType
            // 타입 강제 체크 파일 업데이트
            writeProjectTypeMarker(at: newPath, type: newType)
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
        project.addInfoLog("DEBUG: 프로젝트 타입: \(project.projectType.rawValue)")
        project.addInfoLog("DEBUG: 프로젝트 경로: \(project.path)")
        project.addInfoLog("DEBUG: 포트: \(project.port)")
        
        // 경로 유효성 검사
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: project.path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            project.status = .error
            project.addErrorLog("유효하지 않은 프로젝트 경로: \(project.path)")
            self.errorMessage = "유효하지 않은 프로젝트 경로: \(project.path)"
            self.showingErrorAlert = true
            return
        }
        
        // React Native 프로젝트 검증
        guard isValidProjectPath(path: project.path) else {
            project.status = .error
            project.addErrorLog("React Native/Expo 프로젝트가 아닙니다: \(project.path)")
            self.errorMessage = "React Native 또는 Expo 프로젝트가 아닙니다."
            self.showingErrorAlert = true
            return
        }
        
        // 포트가 사용 중인지 확인 (자동 변경 안함)
        if !isPortAvailable(project.port) {
            project.status = .error
            project.addErrorLog("포트 \(project.port)가 이미 사용 중입니다. 다른 포트로 변경하거나 해당 포트를 사용하는 프로세스를 중지해주세요.")
            self.errorMessage = "포트 \(project.port)가 이미 사용 중입니다. 프로젝트 설정에서 다른 포트로 변경해주세요."
            self.showingErrorAlert = true
            return
        }
        
        // 포트가 사용 가능한 경우 재시도 횟수 리셋
        project.retryCount = 0
        
        project.status = .starting
        project.clearLogs()
        
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.currentDirectoryPath = project.path
        
        // 개선된 환경 변수 설정 (대화형 모드 활성화)
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["FORCE_COLOR"] = "1"
        
        // 대화형 모드를 위해 CI 환경변수 제거
        environment.removeValue(forKey: "CI")
        
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
        
        // Metro를 특정 포트로 시작 (대화형 모드 기본 설정)
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        // Node.js 경로 확인 및 설정
        let nodePath = getNodePath()
        let command: String
        if project.projectType == .expo {
            command = "\(nodePath) node_modules/.bin/expo start --port \(project.port) --max-workers=1"
        } else {
            command = "\(nodePath) node_modules/.bin/react-native start --port \(project.port)"
        }
        process.arguments = ["-c", command]
        
        project.addInfoLog("실행 명령어: \(command)")
        project.addInfoLog("작업 디렉토리: \(project.path)")
        project.addInfoLog("🎯 대화형 모드 활성화됨 - 다음 명령어를 사용할 수 있습니다:")
        project.addInfoLog("   r - 앱 리로드")
        project.addInfoLog("   i - iOS 시뮬레이터에서 앱 실행")
        project.addInfoLog("   a - Android 에뮬레이터에서 앱 실행")
        project.addInfoLog("   d - 개발자 메뉴 열기")
        
        // 출력 모니터링 개선
        pipe.fileHandleForReading.readabilityHandler = { [weak project, weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // 로그 타입 결정
                        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        let lowerOutput = trimmedOutput.lowercased()
                        
                        let logType: LogType
                        if lowerOutput.contains("error") || lowerOutput.contains("fail") || lowerOutput.contains("eaddrinuse") {
                            logType = .error
                        } else if lowerOutput.contains("warn") || lowerOutput.contains("deprecated") {
                            logType = .warning
                        } else if lowerOutput.contains("ready") || lowerOutput.contains("success") || lowerOutput.contains("complete") {
                            logType = .success
                        } else {
                            logType = .info
                        }
                        
                        project?.addLog(trimmedOutput, type: logType)
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
                        project?.addSuccessLog("✅ Metro가 성공적으로 시작되었습니다!")
                        
                        // 성공 시 재시도 로직 중단
                        project?.shouldRetry = false
                    }
                    
                    // 포트 사용 중 오류 감지 (자동 재시도 제거)
                    if lowerOutput.contains("eaddrinuse") || 
                       (lowerOutput.contains("port") && lowerOutput.contains("use") && 
                        !lowerOutput.contains("waiting on http://localhost") && 
                        !lowerOutput.contains("metro is running")) {
                        
                        project?.status = .error
                        project?.shouldRetry = false
                        project?.addErrorLog("포트 \(project?.port ?? 0)가 이미 사용 중입니다. 프로젝트 설정에서 다른 포트로 변경해주세요.")
                    }
                    
                    // Expo 특정 오류 감지
                    if lowerOutput.contains("configerror") || lowerOutput.contains("cannot determine") || 
                       lowerOutput.contains("expo") && lowerOutput.contains("not installed") {
                        project?.status = .error
                        project?.addErrorLog("이 프로젝트는 React Native CLI 프로젝트일 수 있습니다.")
                        project?.addInfoLog("💡 프로젝트를 편집하여 'React Native CLI'로 변경해보세요.")
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
                        project?.addErrorLog(output.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        // npx 관련 메시지는 더 이상 사용하지 않음
                        
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
                    project?.addInfoLog("프로세스가 예기치 않게 종료되었습니다.")
                } else if project?.status != .error {
                    project?.status = .stopped
                }
                project?.process = nil
            }
        }
        
        do {
            try process.run()
            project.process = process
            project.addInfoLog("Metro 시작 중... 포트: \(project.port)")
            
        // 5초 후에도 여전히 starting 상태면 타임아웃 체크
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if project.status == .starting {
                    project.addInfoLog("시작 시간이 오래 걸리고 있습니다. 로그를 확인하세요.")
                }
            }
            
        } catch let error as NSError {
            project.status = .error
            project.addErrorLog(" Metro 시작 실패 - \(error.localizedDescription)")
            self.errorMessage = "Metro 시작 실패: \(error.localizedDescription)"
            self.showingErrorAlert = true
        } catch {
            project.status = .error
            project.addErrorLog(" 알 수 없는 오류로 Metro 시작 실패")
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
        project.addInfoLog("Metro 중지됨")
    }
    
    func stopAllMetroServers() {
        Logger.debug("전체 Metro 서버 종료 시작")
        
        // 실행 중인 모든 프로젝트 중지
        for project in projects {
            if project.isRunning {
                if let process = project.process {
                    // 내부 프로세스인 경우
                    process.terminate()
                    project.addInfoLog("🛑 Metro 서버 중지됨 (내부 프로세스)")
                } else if project.isExternalProcess, let pid = project.externalProcessId {
                    // 외부 프로세스인 경우
                    let task = Process()
                    task.launchPath = "/bin/kill"
                    task.arguments = ["\(pid)"]
                    
                    do {
                        try task.run()
                        task.waitUntilExit()
                        project.addInfoLog("🛑 Metro 서버 중지됨 (외부 프로세스 PID: \(pid))")
                    } catch {
                        project.addErrorLog("❌ 외부 프로세스 종료 실패: \(error.localizedDescription)")
                    }
                }
                
                project.isRunning = false
                project.status = .stopped
                project.process = nil
                project.isExternalProcess = false
                project.externalProcessId = nil
            }
        }
        
        // 포트 스캔으로 남은 Metro 프로세스 확인 및 종료
        let metroPorts = [8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089, 8090, 8091, 8092, 8093, 8094, 8095, 8096]
        
        for port in metroPorts {
            if let pid = getPIDByPort(port: port) {
                let task = Process()
                task.launchPath = "/bin/kill"
                task.arguments = ["\(pid)"]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    Logger.debug("포트 \(port)의 Metro 프로세스 종료됨 (PID: \(pid))")
                } catch {
                    Logger.debug("포트 \(port)의 Metro 프로세스 종료 실패: \(error.localizedDescription)")
                }
            }
        }
        
        Logger.debug("전체 Metro 서버 종료 완료")
        
        // 프로젝트 상태 업데이트 및 저장
        DispatchQueue.main.async {
            self.saveProjects()
        }
    }
    
    func forceKillAllMetroProcesses() {
        Logger.debug("모든 Metro 프로세스 강제 종료 시작")
        
        // 먼저 일반 종료 시도
        stopAllMetroServers()
        
        // 모든 Metro 관련 프로세스를 강제로 찾아서 종료
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pkill -f 'metro\\|expo.*start\\|react-native.*start' || true"]
        
        do {
            try task.run()
            task.waitUntilExit()
            Logger.success("모든 Metro 관련 프로세스 강제 종료 완료")
        } catch {
            Logger.error("Metro 프로세스 강제 종료 실패: \(error.localizedDescription)")
        }
        
        // 모든 프로젝트 상태를 중지로 업데이트
        DispatchQueue.main.async {
            for project in self.projects {
                project.isRunning = false
                project.status = .stopped
                project.process = nil
                project.isExternalProcess = false
                project.externalProcessId = nil
                project.addInfoLog("🔴 강제 종료됨")
            }
            self.saveProjects()
            
            // 성공 메시지 표시
            self.errorMessage = "모든 Metro 프로세스가 강제 종료되었습니다."
            self.showingErrorAlert = true
        }
    }
    
    func stopAllMetroServersAndClear() {
        Logger.debug("모든 Metro 서버 종료 및 리스트 정리 시작")
        
        // 먼저 모든 Metro 프로세스 강제 종료
        forceKillAllMetroProcesses()
        
        // 약간의 지연 후 모든 프로젝트 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.projects.removeAll()
            self.selectedProject = nil
            self.saveProjects()
            
            Logger.success("모든 프로젝트가 리스트에서 제거되었습니다.")
            self.errorMessage = "모든 Metro 서버가 종료되고 프로젝트 리스트가 정리되었습니다."
            self.showingErrorAlert = true
        }
    }
    
    func clearLogs(for project: MetroProject) {
        project.clearLogs()
    }
    
    
    // 번들 URL 문제 자동 해결 함수들 추가
    func autoFixBundleURL(for project: MetroProject) {
        project.addInfoLog("🔧 번들 URL 문제 자동 해결 시작...")
        
        // 1. Metro 서버 연결 확인
        checkMetroConnection(for: project) { isConnected in
            if isConnected {
                // 2. Metro 캐시 클리어
                self.clearMetroCache(for: project) {
                    // 3. 잠시 대기 후 앱 리로드
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.reloadApp(for: project) {
                            // 4. 최종 상태 확인
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self.checkMetroStatus(for: project)
                            }
                        }
                    }
                }
            } else {
                project.addErrorLog("❌ Metro 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.")
            }
        }
    }
    
    private func checkMetroConnection(for project: MetroProject, completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.launchPath = "/usr/bin/curl"
        task.arguments = ["-s", "--connect-timeout", "3", "http://localhost:\(project.port)/status"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        DispatchQueue.global(qos: .utility).async {
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let isConnected = task.terminationStatus == 0 && !data.isEmpty
                
                DispatchQueue.main.async {
                    completion(isConnected)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    private func clearMetroCache(for project: MetroProject, completion: @escaping () -> Void) {
        project.addInfoLog("📦 Metro 캐시 클리어 중...")
        
        let task = Process()
        task.launchPath = "/usr/bin/curl"
        task.arguments = ["-X", "POST", "-s", "--connect-timeout", "5", "http://localhost:\(project.port)/reset-cache"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        DispatchQueue.global(qos: .utility).async {
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        project.addSuccessLog("✅ Metro 캐시 클리어 완료")
                        if !output.isEmpty {
                            project.addInfoLog("응답: \(output)")
                        }
                    } else {
                        project.addErrorLog("캐시 클리어 실패 - HTTP 오류")
                    }
                    completion()
                }
            } catch {
                DispatchQueue.main.async {
                    project.addErrorLog("캐시 클리어 네트워크 오류 - \(error.localizedDescription)")
                    completion()
                }
            }
        }
    }
    
    private func reloadApp(for project: MetroProject, completion: @escaping () -> Void) {
        project.addInfoLog("🔄 앱 리로드 명령 전송 중...")
        
        let task = Process()
        task.launchPath = "/usr/bin/curl"
        task.arguments = ["-X", "POST", "-s", "--connect-timeout", "5", "http://localhost:\(project.port)/reload"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        DispatchQueue.global(qos: .utility).async {
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        project.addSuccessLog("✅ 리로드 명령 전송 완료")
                        if output.contains("No apps connected") {
                            project.addWarningLog("연결된 앱이 없습니다. 시뮬레이터나 디바이스에서 앱이 실행중인지 확인해주세요.")
                        } else if !output.isEmpty {
                            project.addInfoLog("응답: \(output)")
                        }
                    } else {
                        project.addErrorLog("리로드 명령 전송 실패 - HTTP 오류")
                    }
                    completion()
                }
            } catch {
                DispatchQueue.main.async {
                    project.addErrorLog("리로드 명령 네트워크 오류 - \(error.localizedDescription)")
                    completion()
                }
            }
        }
    }
    
    private func checkMetroStatus(for project: MetroProject) {
        project.addInfoLog("🔍 Metro 서버 상태 확인 중...")
        
        let task = Process()
        task.launchPath = "/usr/bin/curl"
        task.arguments = ["-s", "--connect-timeout", "5", "http://localhost:\(project.port)/status"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        DispatchQueue.global(qos: .utility).async {
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 && !output.isEmpty {
                        if output.contains("packager-status:running") || output.contains("Metro") {
                            project.addSuccessLog("✅ Metro 서버 정상 실행 중")
                            project.addSuccessLog("🎉 번들 URL 문제 해결 완료!")
                            
                            // 번들 서버 URL 정보 제공
                            project.addInfoLog("📱 앱에서 다음 URL로 연결해보세요:")
                            project.addInfoLog("   iOS: http://localhost:\(project.port)/index.bundle?platform=ios")
                            project.addInfoLog("   Android: http://localhost:\(project.port)/index.bundle?platform=android")
                        } else {
                            project.addWarningLog("Metro 서버가 응답하지만 상태가 불명확합니다.")
                            project.addInfoLog("응답: \(output)")
                        }
                    } else {
                        project.addErrorLog("Metro 서버 상태 확인 실패 - 서버가 응답하지 않습니다.")
                        project.addInfoLog("💡 해결방안:")
                        project.addInfoLog("   1. Metro 서버를 다시 시작해보세요")
                        project.addInfoLog("   2. 포트 \(project.port)가 올바른지 확인해주세요")
                        project.addInfoLog("   3. iOS 앱을 수동으로 다시 시작해보세요")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    project.addErrorLog("Metro 서버 상태 확인 네트워크 오류 - \(error.localizedDescription)")
                }
            }
        }
    }
    
    // iOS/Android 앱 자동 실행 함수 - 개선된 버전
    func runOniOS(for project: MetroProject) {
        project.addInfoLog("📱 iOS 시뮬레이터에서 앱 실행 중...")
        
        // node_modules 바이너리 직접 호출로 대체 (npx 제거)
        let nvmScript: String
        if project.projectType == .expo {
            nvmScript = """
            cd "\(project.path)"
            node node_modules/.bin/expo run:ios
            """
        } else {
            nvmScript = """
            cd "\(project.path)"
            node node_modules/.bin/react-native run-ios --simulator='iPhone 16'
            """
        }
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", nvmScript]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            // 비동기로 출력 모니터링
            pipe.fileHandleForReading.readabilityHandler = { [weak project] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        project?.addInfoLog(output.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
            
            project.addSuccessLog("✅ iOS 앱 실행 명령 시작됨")
        } catch {
            project.addErrorLog("❌ iOS 앱 실행 명령 전송 실패: \(error.localizedDescription)")
        }
    }
    
    func runOnAndroid(for project: MetroProject) {
        project.addInfoLog("🤖 Android 에뮬레이터에서 앱 실행 중...")
        
        // node_modules 바이너리 직접 호출로 대체 (npx 제거)
        let nvmScript: String
        if project.projectType == .expo {
            nvmScript = """
            cd "\(project.path)"
            node node_modules/.bin/expo run:android
            """
        } else {
            nvmScript = """
            cd "\(project.path)"
            node node_modules/.bin/react-native run-android
            """
        }
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", nvmScript]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            // 비동기로 출력 모니터링
            pipe.fileHandleForReading.readabilityHandler = { [weak project] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        project?.addInfoLog(output.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
            
            project.addSuccessLog("✅ Android 앱 실행 명령 시작됨")
        } catch {
            project.addErrorLog("❌ Android 앱 실행 명령 전송 실패: \(error.localizedDescription)")
        }
    }
    
    // 패키지 매니저 자동 감지 후 의존성 설치
    func installProjectDependencies(for project: MetroProject) {
        project.addInfoLog("📦 의존성 설치 시작...")
        let script = """
        set -e
        cd "\(project.path)"
        if [ -f pnpm-lock.yaml ] || [ -f .pnpmfile.cjs ] || [ -d node_modules/.pnpm ]; then
          if command -v pnpm >/dev/null 2>&1; then
            echo "pnpm install"
            pnpm install
            exit 0
          fi
        fi
        if [ -f yarn.lock ]; then
          if command -v yarn >/dev/null 2>&1; then
            echo "yarn install"
            yarn install
            exit 0
          fi
        fi
        if command -v npm >/dev/null 2>&1; then
          echo "npm install"
          npm install
          exit 0
        fi
        echo "no_package_manager"
        exit 1
        """
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            pipe.fileHandleForReading.readabilityHandler = { [weak project] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { project?.addInfoLog(trimmed) }
                    }
                }
            }
            task.waitUntilExit()
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    project.addSuccessLog("✅ 의존성 설치 완료")
                } else {
                    project.addErrorLog("❌ 의존성 설치 실패 - 패키지 매니저를 찾을 수 없습니다")
                }
            }
        } catch {
            project.addErrorLog("❌ 의존성 설치 실행 실패: \(error.localizedDescription)")
        }
    }
    
    // 중복 프로젝트 정리
    private func cleanupDuplicateProjects() {
        var projectsToRemove: [MetroProject] = []
        
        // 포트별로 그룹화하여 중복 확인
        let groupedByPort = Dictionary(grouping: projects) { $0.port }
        
        for (port, portProjects) in groupedByPort {
            if portProjects.count > 1 {
                NSLog("DEBUG: 포트 \(port)에서 \(portProjects.count)개의 프로젝트 발견")
                
                // 실행 중인 프로젝트 우선 유지
                let runningProjects = portProjects.filter { $0.isRunning }
                let stoppedProjects = portProjects.filter { !$0.isRunning }
                
                // 외부 프로세스와 내부 프로세스 구분
                let externalProjects = portProjects.filter { $0.isExternalProcess }
                let internalProjects = portProjects.filter { !$0.isExternalProcess }
                
                // 정리 규칙:
                // 1. 실행 중인 내부 프로젝트가 있으면 외부 프로세스 제거
                // 2. 실행 중인 프로젝트가 여러 개면 외부 프로세스 제거
                // 3. 중지된 중복 프로젝트 제거
                
                if let runningInternal = internalProjects.first(where: { $0.isRunning }) {
                    // 실행 중인 내부 프로젝트가 있으면 외부 프로세스들 제거
                    projectsToRemove.append(contentsOf: externalProjects)
                    NSLog("DEBUG: 포트 \(port) - 실행 중인 내부 프로젝트 유지, 외부 프로세스 \(externalProjects.count)개 제거")
                } else if runningProjects.count > 1 {
                    // 실행 중인 프로젝트가 여러 개면 외부 프로세스들 제거
                    projectsToRemove.append(contentsOf: externalProjects)
                    NSLog("DEBUG: 포트 \(port) - 실행 중인 프로젝트 \(runningProjects.count)개 중 외부 프로세스 \(externalProjects.count)개 제거")
                } else if stoppedProjects.count > 1 {
                    // 중지된 프로젝트가 여러 개면 첫 번째만 유지
                    let toRemove = Array(stoppedProjects.dropFirst())
                    projectsToRemove.append(contentsOf: toRemove)
                    NSLog("DEBUG: 포트 \(port) - 중지된 중복 프로젝트 \(toRemove.count)개 제거")
                }
            }
        }
        
        // 중복 프로젝트 제거
        for project in projectsToRemove {
            projects.removeAll { $0.id == project.id }
            NSLog("DEBUG: 중복 프로젝트 제거 - \(project.name) (포트: \(project.port))")
        }
        
        if !projectsToRemove.isEmpty {
            saveProjects()
            NSLog("DEBUG: 총 \(projectsToRemove.count)개의 중복 프로젝트 정리 완료")
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
        // 체크 파일 우선 적용
        if let forcedType = readProjectTypeMarker(at: path) {
            Logger.debug("강제 타입 마커 감지: \(forcedType.rawValue)")
            return forcedType == .expo
        }
        
        // TodayLucky 프로젝트 특별 처리
        if path.contains("TodayLucky") {
            Logger.debug("TodayLucky 프로젝트 특별 감지: Expo로 강제 설정")
            return true
        }
        
        // Expo 설정 파일들 확인
        let expoConfigPath = "\(path)/app.json"
        let expoConfigPathTS = "\(path)/app.config.js"
        let expoConfigPathJS = "\(path)/app.config.ts"
        let expoConfigPathMJS = "\(path)/app.config.mjs"
        let packageJsonPath = "\(path)/package.json"
        let expoJsonPath = "\(path)/expo.json"
        
        // expo.json이 있으면 확실히 Expo 프로젝트
        if FileManager.default.fileExists(atPath: expoJsonPath) {
            Logger.debug("Expo 프로젝트 감지: expo.json 파일 존재")
            return true
        }
        
        // app.config.js/ts/mjs가 있으면 Expo 프로젝트로 간주
        if FileManager.default.fileExists(atPath: expoConfigPathTS) ||
           FileManager.default.fileExists(atPath: expoConfigPathJS) ||
           FileManager.default.fileExists(atPath: expoConfigPathMJS) {
            Logger.debug("Expo 프로젝트 감지: app.config 파일 존재")
            return true
        }
        
        // app.json이 있는 경우, 내용을 확인해서 Expo 설정인지 판단
        if FileManager.default.fileExists(atPath: expoConfigPath) {
            do {
                let appJsonData = try Data(contentsOf: URL(fileURLWithPath: expoConfigPath))
                if let appJson = try JSONSerialization.jsonObject(with: appJsonData) as? [String: Any] {
                    // Expo 프로젝트의 app.json에는 보통 expo 키가 있음
                    if appJson["expo"] != nil {
                        Logger.debug("Expo 프로젝트 감지: app.json에 expo 키 존재")
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
                    // 또는 name과 slug가 있으면 Expo 프로젝트일 가능성이 높음
                    if appJson["name"] != nil && appJson["slug"] != nil {
                        return true
                    }
                }
            } catch {
                Logger.error("app.json 파싱 실패: \(error)")
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
                        // @expo/cli가 있으면 Expo 프로젝트
                        if dependencies["@expo/cli"] != nil {
                            return true
                        }
                        // expo-router가 있으면 Expo 프로젝트
                        if dependencies["expo-router"] != nil {
                            return true
                        }
                        // expo-constants가 있으면 Expo 프로젝트
                        if dependencies["expo-constants"] != nil {
                            return true
                        }
                        // expo-status-bar가 있으면 Expo 프로젝트
                        if dependencies["expo-status-bar"] != nil {
                            Logger.debug("Expo 프로젝트 감지: package.json에 expo-status-bar 의존성 존재")
                            return true
                        }
                        // expo-splash-screen이 있으면 Expo 프로젝트
                        if dependencies["expo-splash-screen"] != nil {
                            Logger.debug("Expo 프로젝트 감지: package.json에 expo-splash-screen 의존성 존재")
                            return true
                        }
                        // expo-linking이 있으면 Expo 프로젝트
                        if dependencies["expo-linking"] != nil {
                            Logger.debug("Expo 프로젝트 감지: package.json에 expo-linking 의존성 존재")
                            return true
                        }
                        // expo-font가 있으면 Expo 프로젝트
                        if dependencies["expo-font"] != nil {
                            Logger.debug("Expo 프로젝트 감지: package.json에 expo-font 의존성 존재")
                            return true
                        }
                        // expo-image가 있으면 Expo 프로젝트
                        if dependencies["expo-image"] != nil {
                            Logger.debug("Expo 프로젝트 감지: package.json에 expo-image 의존성 존재")
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
                        if devDependencies["@expo/cli"] != nil {
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
                    
                    // name 필드에서 expo 확인
                    if let name = packageJson["name"] as? String {
                        if name.lowercased().contains("expo") {
                            Logger.debug("Expo 프로젝트 감지: package.json name에 expo 포함 (\(name))")
                            return true
                        }
                    }
                    
                    // main 필드에서 expo 확인
                    if let main = packageJson["main"] as? String {
                        if main.contains("expo") {
                            Logger.debug("Expo 프로젝트 감지: package.json main에 expo 포함 (\(main))")
                            return true
                        }
                    }
                }
            } catch {
                // JSON 파싱 실패 시 파일 기반으로만 판단
                Logger.error("package.json 파싱 실패: \(error)")
            }
        }
        
        // 추가 파일 기반 확인
        let expoDirPath = "\(path)/.expo"
        if FileManager.default.fileExists(atPath: expoDirPath) {
            Logger.debug("Expo 프로젝트 감지: .expo 디렉토리 존재")
            return true
        }
        
        let metroConfigPath = "\(path)/metro.config.js"
        if FileManager.default.fileExists(atPath: metroConfigPath) {
            // metro.config.js 내용에서 expo 확인
            do {
                let metroConfigContent = try String(contentsOfFile: metroConfigPath, encoding: .utf8)
                if metroConfigContent.contains("expo") {
                    return true
                }
            } catch {
                Logger.error("metro.config.js 읽기 실패: \(error)")
            }
        }
        
        Logger.debug("Expo 프로젝트 감지 실패: 모든 조건 불만족")
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
            Logger.error("package.json 읽기 실패: \(error.localizedDescription)")
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
        Logger.debug("프로젝트 저장됨 - \(data)")
    }
    
    // 사용자 설정 프로젝트 타입 저장/로드
    private func saveUserProjectType(path: String, projectType: ProjectType) {
        var userProjectTypes = UserDefaults.standard.dictionary(forKey: "UserProjectTypes") as? [String: String] ?? [:]
        userProjectTypes[path] = projectType.rawValue
        UserDefaults.standard.set(userProjectTypes, forKey: "UserProjectTypes")
        Logger.debug("사용자 프로젝트 타입 저장: \(path) -> \(projectType.rawValue)")
    }
    
    private func getUserProjectType(path: String) -> ProjectType? {
        let userProjectTypes = UserDefaults.standard.dictionary(forKey: "UserProjectTypes") as? [String: String] ?? [:]
        if let typeString = userProjectTypes[path], let projectType = ProjectType(rawValue: typeString) {
            Logger.debug("사용자 프로젝트 타입 로드: \(path) -> \(projectType.rawValue)")
            return projectType
        }
        return nil
    }
    
    // 사용자가 프로젝트 타입을 수동으로 변경할 때 호출
    func updateProjectType(for project: MetroProject, to newType: ProjectType) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].projectType = newType
            saveUserProjectType(path: project.path, projectType: newType)
            saveProjects()
            Logger.debug("프로젝트 타입 업데이트: \(project.name) -> \(newType.rawValue)")
        }
    }
    
    // 옵션 저장/로드
    func saveOptions() {
        UserDefaults.standard.set(autoAddExternalProcesses, forKey: "AutoAddExternal")
        UserDefaults.standard.set(hideDuplicatePorts, forKey: "HideDuplicatePorts")
    }
    
    private func loadOptions() {
        if UserDefaults.standard.object(forKey: "AutoAddExternal") != nil {
            autoAddExternalProcesses = UserDefaults.standard.bool(forKey: "AutoAddExternal")
        }
        if UserDefaults.standard.object(forKey: "HideDuplicatePorts") != nil {
            hideDuplicatePorts = UserDefaults.standard.bool(forKey: "HideDuplicatePorts")
        }
    }
    
    private func loadProjects() {
        guard let data = UserDefaults.standard.array(forKey: "MetroProjects") as? [[String: Any]] else { return }
        
        projects = data.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let path = dict["path"] as? String,
                  let port = dict["port"] as? Int else { return nil }
            
            // 1. 사용자 설정 우선 확인
            if let userProjectType = getUserProjectType(path: path) {
                Logger.debug("사용자 설정 프로젝트 타입 사용: \(name) -> \(userProjectType.rawValue)")
                return MetroProject(name: name, path: path, port: port, projectType: userProjectType)
            }
            
            // 2. 기존 프로젝트 호환성: projectType이 없으면 자동 감지
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
            Logger.error("쉘 경로 가져오기 실패: \(error)")
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
        Logger.debug("Metro 프로세스 감지 시작...")
        
        // UI 피드백은 수동 감지 시에만 표시
        if showUI {
            DispatchQueue.main.async {
                self.errorMessage = "프로세스 및 포트 스캔 중..."
                self.showingErrorAlert = true
            }
        }
        
        // 1. 포트 기반 감지 (더 정확함)
        if autoAddExternalProcesses {
            detectAllActiveServers(showUI: showUI)
        }
        
        // 2. 프로세스 기반 감지 (Metro 관련만)
        if autoAddExternalProcesses {
            detectMetroProcessesByName()
        }
        
        // 3. 포트 기반 Metro 서버 감지 추가
        if autoAddExternalProcesses {
            detectMetroServersByPort()
        }
    }
    
    // 모든 활성 서버 감지 (8080-8100 포트 범위)
    private func detectAllActiveServers(showUI: Bool = true) {
        Logger.debug("전체 포트 스캔 시작 (8080-8100)...")
        
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i", ":8080-8100", "-P", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                Logger.debug("lsof 출력:")
                NSLog("%@", output)
                parsePortUsageData(output, showUI: showUI)
            }
        } catch {
            Logger.error("lsof 명령어 실행 오류: \(error)")
        }
    }
    
    // Metro 관련 프로세스만 검색 (메인 Node 프로세스만)
    private func detectMetroProcessesByName() {
        Logger.debug("Metro 관련 프로세스 검색...")
        
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
        
        // 감지된 서버들을 프로젝트로 반영 (중복 방지: 업데이트 우선)
        for server in detectedServers {
            // 이미 추가된 프로젝트인지 확인 (포트 + 이름 기반)
            let extractedName = extractProjectNameFromCommand(server.command)
            let isAlreadyAdded = projects.contains { project in
                if project.port == server.port {
                    // 같은 포트에서 같은 이름의 프로젝트가 있으면 중복으로 간주
                    if !extractedName.isEmpty && project.name.contains(extractedName) {
                        return true
                    }
                    // 외부 프로세스가 이미 있으면 중복으로 간주
                    if project.isExternalProcess {
                        return true
                    }
                }
                return false
            }
            
            // 추가로: 이미 실행 중인 프로젝트가 같은 포트를 사용하는지 확인
            let hasRunningProjectOnSamePort = projects.contains {
                $0.port == server.port && $0.isRunning && !$0.isExternalProcess
            }
            
            // upsert 로직: 기존 항목 업데이트, 없으면 생성
            upsertExternalProject(port: server.port, pid: server.pid)
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

    // 중복 방지용: 외부 프로세스 정보를 기존 항목에 병합/갱신
    private func upsertExternalProject(port: Int, pid: Int) {
        let info = getProjectInfoFromPID(pid)
        let projectPath = info?.path ?? "/unknown"
        let projectName = info?.name ?? "Metro Server (포트 \(port))"
        
        // 사용자 설정 우선 확인
        let projectType: ProjectType
        if let userProjectType = getUserProjectType(path: projectPath) {
            projectType = userProjectType
            Logger.debug("외부 프로세스 감지 - 사용자 설정 프로젝트 타입 사용: \(projectName) -> \(projectType.rawValue)")
        } else {
            projectType = info?.type ?? .reactNativeCLI
            Logger.debug("외부 프로세스 감지 - 자동 감지 프로젝트 타입: \(projectName) -> \(projectType.rawValue)")
        }
        
        // 우선 경로 매칭, 없으면 포트 매칭
        if let index = projects.firstIndex(where: { $0.path == projectPath && projectPath != "/unknown" }) ??
                       projects.firstIndex(where: { $0.port == port }) {
            let existing = projects[index]
            let wasExternal = existing.isExternalProcess
            existing.isExternalProcess = true
            existing.externalProcessId = pid
            existing.isRunning = true
            existing.status = .running
            if existing.path == "/unknown" && projectPath != "/unknown" {
                existing.path = projectPath
            }
            if existing.name.isEmpty || existing.name.hasPrefix("Metro Server") {
                existing.name = projectName
            }
            // 기존 프로젝트의 타입은 변경하지 않음 (사용자 설정 보존)
            Logger.debug("외부 프로세스 감지 - 기존 프로젝트 타입 유지: \(existing.name) -> \(existing.projectType.rawValue)")
            NSLog("DEBUG: upsert - 기존 프로젝트 갱신 (포트: \(port), 경로: \(existing.path))")
            
            // 새로 외부 프로세스가 된 경우 로그 스트림 연결
            if !wasExternal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.attachExternalLogs(for: existing)
                }
            }
        } else {
            // 내부 항목이 같은 포트에 있다면 새로 만들지 않음
            if projects.contains(where: { $0.port == port && !$0.isExternalProcess }) {
                NSLog("DEBUG: upsert - 동일 포트 내부 프로젝트 존재, 외부 항목 생성 생략")
                return
            }
            let project = MetroProject(name: projectName, path: projectPath, port: port, projectType: projectType)
            project.isExternalProcess = true
            project.externalProcessId = pid
            project.isRunning = true
            project.status = .running
            projects.append(project)
            NSLog("DEBUG: upsert - 새 외부 프로젝트 생성 (포트: \(port), 경로: \(projectPath))")
            
            // 새 외부 프로젝트에 로그 스트림 연결
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.attachExternalLogs(for: project)
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
                // PID 확인 후 upsert로 일원화
                if let pid = getPIDByPort(port: port) {
                    upsertExternalProject(port: port, pid: pid)
                }
            } else {
                // 포트에서 서버가 실행되지 않는 경우, 해당 포트의 프로젝트 상태를 중지로 업데이트
                if let existingProjectIndex = projects.firstIndex(where: { $0.port == port }) {
                    DispatchQueue.main.async {
                        let project = self.projects[existingProjectIndex]
                        if project.isRunning || project.status == .running {
                            project.isRunning = false
                            project.status = .stopped
                            project.addInfoLog("포트 \(port)에서 Metro 서버가 중지되었습니다.")
                            NSLog("DEBUG: 포트 \(port) - 프로젝트 상태 업데이트됨 (중지됨)")
                        }
                    }
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
    
    private func getPIDByPort(port: Int) -> Int? {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-ti", "tcp:\(port)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = Int(s.components(separatedBy: .newlines).first ?? "") {
                return pid
            }
        } catch {}
        return nil
    }
    
    private func isMetroServerRunning(on port: Int) -> Bool {
        NSLog("DEBUG: 포트 \(port) Metro 서버 확인 시작")
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "curl -s http://localhost:\(port)/status || curl -s http://localhost:\(port)/"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let response = String(data: data, encoding: .utf8) {
                NSLog("DEBUG: 포트 \(port) 응답: \(response)")
                // Metro 서버 응답 확인 - 더 관대한 조건
                let isMetro = !response.isEmpty && (
                    response.contains("Metro") || 
                    response.contains("React Native") || 
                    response.contains("expo") ||
                    response.contains("packager-status") ||
                    response.contains("running") ||
                    response.contains("StoryLingo") ||  // 프로젝트 이름이 포함된 경우
                    response.contains("<!DOCTYPE html>")  // HTML 응답인 경우
                )
                NSLog("DEBUG: 포트 \(port) Metro 서버 감지 결과: \(isMetro)")
                return isMetro
            }
        } catch {
            NSLog("DEBUG: 포트 \(port) curl 오류: \(error)")
        }
        
        // curl이 실패한 경우 lsof로 포트 사용 확인
        NSLog("DEBUG: 포트 \(port) curl 실패, lsof로 확인")
        let lsofTask = Process()
        lsofTask.launchPath = "/usr/sbin/lsof"
        lsofTask.arguments = ["-i", ":\(port)", "-P", "-n"]
        
        let lsofPipe = Pipe()
        lsofTask.standardOutput = lsofPipe
        
        do {
            try lsofTask.run()
            let lsofData = lsofPipe.fileHandleForReading.readDataToEndOfFile()
            if let lsofOutput = String(data: lsofData, encoding: .utf8) {
                NSLog("DEBUG: 포트 \(port) lsof 출력: \(lsofOutput)")
                let isListening = lsofOutput.contains("LISTEN") && lsofOutput.contains("node")
                NSLog("DEBUG: 포트 \(port) lsof 감지 결과: \(isListening)")
                return isListening
            }
        } catch {
            NSLog("DEBUG: 포트 \(port) lsof 오류: \(error)")
        }
        
        NSLog("DEBUG: 포트 \(port) Metro 서버 없음")
        return false
    }
    
    private func getProjectPathFromMetroServer(port: Int) -> String {
        NSLog("DEBUG: 포트 \(port)에서 프로젝트 경로 추출 시도")
        
        // 1. ps 명령어로 해당 포트를 사용하는 프로세스의 작업 디렉토리 확인
        let psTask = Process()
        psTask.launchPath = "/bin/bash"
        psTask.arguments = ["-c", "ps -p $(lsof -ti:\(port)) -o cwd= 2>/dev/null | head -1"]
        
        let psPipe = Pipe()
        psTask.standardOutput = psPipe
        
        do {
            try psTask.run()
            let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
            if let psOutput = String(data: psData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if !psOutput.isEmpty && psOutput != "/" {
                    NSLog("DEBUG: 포트 \(port)에서 추출된 프로젝트 경로: \(psOutput)")
                    return psOutput
                }
            }
        } catch {
            NSLog("DEBUG: 포트 \(port) ps 명령어 오류: \(error)")
        }
        
        // 2. lsof로 프로세스 정보 확인
        let lsofTask = Process()
        lsofTask.launchPath = "/usr/sbin/lsof"
        lsofTask.arguments = ["-i", ":\(port)", "-P", "-n", "-F", "p"]
        
        let lsofPipe = Pipe()
        lsofTask.standardOutput = lsofPipe
        
        do {
            try lsofTask.run()
            let lsofData = lsofPipe.fileHandleForReading.readDataToEndOfFile()
            if let lsofOutput = String(data: lsofData, encoding: .utf8) {
                // PID 추출
                let lines = lsofOutput.components(separatedBy: .newlines)
                for line in lines {
                    if line.hasPrefix("p") {
                        let pid = String(line.dropFirst())
                        if let pidInt = Int(pid) {
                            // PID로 프로세스의 작업 디렉토리 확인
                            let pwdxTask = Process()
                            pwdxTask.launchPath = "/bin/bash"
                            pwdxTask.arguments = ["-c", "pwdx \(pidInt) 2>/dev/null | cut -d: -f2 | tr -d ' '"]
                            
                            let pwdxPipe = Pipe()
                            pwdxTask.standardOutput = pwdxPipe
                            
                            do {
                                try pwdxTask.run()
                                let pwdxData = pwdxPipe.fileHandleForReading.readDataToEndOfFile()
                                if let pwdxOutput = String(data: pwdxData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                                    if !pwdxOutput.isEmpty && pwdxOutput != "/" {
                                        NSLog("DEBUG: 포트 \(port) PID \(pidInt)에서 추출된 프로젝트 경로: \(pwdxOutput)")
                                        return pwdxOutput
                                    }
                                }
                            } catch {
                                NSLog("DEBUG: 포트 \(port) pwdx 명령어 오류: \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            NSLog("DEBUG: 포트 \(port) lsof 명령어 오류: \(error)")
        }
        
        NSLog("DEBUG: 포트 \(port)에서 프로젝트 경로 추출 실패")
        return "/unknown"
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
                    project.addInfoLog("외부에서 실행 중인 Metro 프로세스가 감지되었습니다.")
                    if let pid = projectInfo.pid {
                        project.addInfoLog("프로세스 ID: \(pid)")
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
                        project.addInfoLog("외부 프로세스가 종료되었습니다.")
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
            Logger.error("프로세스 확인 실패: \(error)")
        }
        
        return false
    }
    
    // MARK: - 외부 프로세스 제어
    func stopExternalMetroProcess(for project: MetroProject) {
        NSLog("DEBUG: 외부 Metro 프로세스 중지 시도 - \(project.name) (포트: \(project.port), PID: \(project.externalProcessId ?? -1))")
        
        guard project.isExternalProcess else {
            NSLog("ERROR: 이 프로젝트는 외부 프로세스가 아닙니다.")
            return
        }
        
        var stopped = false
        
        // PID로 프로세스 종료 시도
        if let pid = project.externalProcessId {
            NSLog("DEBUG: PID \(pid)로 프로세스 종료 시도")
            stopped = killProcess(pid: pid, projectName: project.name)
        } else {
            NSLog("DEBUG: PID가 없어서 포트 기반 종료로 진행")
        }
        
        // PID로 종료되지 않았다면 포트 기반으로 프로세스 찾아서 종료
        if !stopped {
            NSLog("DEBUG: 포트 \(project.port)로 프로세스 종료 시도")
            stopped = killMetroProcessByPort(port: project.port, projectName: project.name)
        }
        
        if stopped {
            DispatchQueue.main.async {
                project.status = .stopped
                project.isRunning = false
                project.addInfoLog("외부 Metro 프로세스가 성공적으로 종료되었습니다.")
                Logger.success("외부 Metro 프로세스 종료됨 - \(project.name)")
            }
        } else {
            DispatchQueue.main.async {
                project.addInfoLog("외부 Metro 프로세스 종료에 실패했습니다.")
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
                    Logger.success("PID \(pid)로 \(projectName) 프로세스 종료 성공")
                } else {
                    // SIGTERM으로 안되면 SIGKILL 시도
                    let forceKillTask = Process()
                    forceKillTask.launchPath = "/bin/kill"
                    forceKillTask.arguments = ["-KILL", "\(pid)"]
                    try? forceKillTask.run()
                    Logger.debug("PID \(pid)로 \(projectName) 프로세스 강제 종료 시도")
                }
            }
            
            return true
        } catch {
            Logger.error("PID \(pid) 프로세스 종료 실패 - \(error)")
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
                    Logger.success("포트 \(port)로 \(projectName) 프로세스 종료 성공")
                } else {
                    // SIGTERM으로 안되면 SIGKILL 시도
                    let forceKillTask = Process()
                    forceKillTask.launchPath = "/bin/bash"
                    forceKillTask.arguments = ["-c", "lsof -ti tcp:\(port) | xargs kill -KILL"]
                    try? forceKillTask.run()
                    Logger.debug("포트 \(port)로 \(projectName) 프로세스 강제 종료 시도")
                }
            }
            
            return true
        } catch {
            Logger.error("포트 \(port) 프로세스 종료 실패 - \(error)")
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
                    project?.addInfoLog("=== 외부 Metro 로그 ===")
                    project?.addInfoLog(logString)
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    project?.addInfoLog("외부 Metro 로그 가져오기 실패: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - 외부 프로세스 로그 스트림 (macOS unified log)
    func isAttachingExternalLogs(for project: MetroProject) -> Bool {
        return externalLogTasks[project.id] != nil
    }
    
    func attachExternalLogs(for project: MetroProject) {
        guard project.isExternalProcess, let pid = project.externalProcessId else { 
            NSLog("DEBUG: 외부 로그 연결 실패 - 외부 프로세스가 아니거나 PID가 없음")
            return 
        }
        
        // 이미 연결돼 있으면 무시
        if externalLogTasks[project.id] != nil { 
            NSLog("DEBUG: 외부 로그 이미 연결됨 - PID: \(pid)")
            return 
        }
        
        NSLog("DEBUG: 외부 로그 스트림 연결 시도 - PID: \(pid)")
        
        // 방법 1: macOS unified log 사용
        let task = Process()
        task.launchPath = "/usr/bin/log"
        task.arguments = [
            "stream",
            "--style", "compact",
            "--level", "debug",
            "--predicate", "processID == \(pid)"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            externalLogTasks[project.id] = task
            project.addSuccessLog("📱 외부 Metro 로그 스트림 연결됨 (PID: \(pid))")
            NSLog("DEBUG: 외부 로그 스트림 시작 성공 - PID: \(pid)")
            
            pipe.fileHandleForReading.readabilityHandler = { [weak self, weak project] handle in
                guard let data = try? handle.readToEnd() ?? handle.availableData, !data.isEmpty else { return }
                let chunk = String(decoding: data, as: UTF8.self)
                DispatchQueue.main.async {
                    chunk.split(separator: "\n", omittingEmptySubsequences: false).forEach { line in
                        let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedLine.isEmpty {
                            project?.addInfoLog(trimmedLine)
                        }
                    }
                }
            }
        } catch {
            NSLog("DEBUG: macOS unified log 실패 - PID: \(pid), 오류: \(error)")
            project.addWarningLog("macOS 로그 스트림 실패, 대체 방법 시도 중...")
            
            // 방법 2: 대체 방법 - 프로세스 출력 직접 캡처
            attachExternalLogsAlternative(for: project, pid: pid)
        }
    }
    
    // 대체 방법: 프로세스 출력 직접 캡처
    private func attachExternalLogsAlternative(for project: MetroProject, pid: Int) {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", String(pid), "-o", "command="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                NSLog("DEBUG: 대체 로그 방법 - 명령어: \(command)")
                project.addInfoLog("📱 외부 Metro 프로세스 감지됨")
                project.addInfoLog("명령어: \(command)")
                
                // 주기적으로 프로세스 상태 확인
                startExternalProcessMonitoring(for: project, pid: pid)
            }
        } catch {
            project.addErrorLog("외부 프로세스 정보 가져오기 실패: \(error.localizedDescription)")
        }
    }
    
    // 외부 프로세스 상태 모니터링
    
    // MARK: - 사용자 명령 처리
    func handleUserCommand(_ command: String, for project: MetroProject) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 단축키 명령 처리
        if let metroCommand = handleMetroShortcut(input: trimmedCommand, for: project) {
            executeMetroCommand(command: metroCommand, for: project)
            return
        }
        
        // 직접 Metro 명령 전송
        if project.isRunning {
            project.addInfoLog("사용자 명령 실행: \(trimmedCommand)")
            sendMetroCommand(trimmedCommand, to: project)
        } else {
            project.addWarningLog("Metro가 실행 중이 아니므로 명령을 실행할 수 없습니다.")
        }
    }
    
    // MARK: - Metro 단축키 처리
    private func handleMetroShortcut(input: String, for project: MetroProject?) -> String? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 단일 문자 단축키 처리
        switch trimmedInput.lowercased() {
        case "r":
            return "reload"
        case "i":
            return "ios"
        case "a":
            return "android"
        case "d":
            return "dev-menu"
        case "j":
            return "debug"
        case "m":
            return "menu"
        // Expo 추가 옵션들
        case "w":
            return "web"
        case "c":
            return "clear"
        case "s":
            return "send"
        case "t":
            return "tunnel"
        case "l":
            return "lan"
        case "o":
            return "localhost"
        case "u":
            return "url"
        case "h":
            return "help"
        case "v":
            return "version"
        case "q":
            return "quit"
        case "x":
            return "exit"
        default:
            return nil
        }
    }
    
    private func executeMetroCommand(command: String, for project: MetroProject?) {
        guard let project = project, project.isRunning else {
            NSLog("DEBUG: 프로젝트가 실행 중이 아니므로 명령을 실행할 수 없습니다.")
            return
        }
        
        NSLog("DEBUG: Metro 명령 실행: \(command)")
        
        switch command {
        case "reload":
            project.addInfoLog("🔄 앱 리로드 명령 실행...")
            sendMetroCommand("r", to: project)
        case "ios":
            project.addInfoLog("📱 iOS 시뮬레이터에서 앱 실행...")
            sendMetroCommand("i", to: project)
        case "android":
            project.addInfoLog("🤖 Android 에뮬레이터에서 앱 실행...")
            sendMetroCommand("a", to: project)
        case "dev-menu":
            project.addInfoLog("⚙️ 개발자 메뉴 열기...")
            sendMetroCommand("d", to: project)
        case "debug":
            project.addInfoLog("🐛 디버그 모드 토글...")
            sendMetroCommand("j", to: project)
        case "menu":
            project.addInfoLog("📋 메뉴 열기...")
            sendMetroCommand("m", to: project)
        // Expo 추가 명령들
        case "web":
            project.addInfoLog("🌐 웹 브라우저에서 앱 실행...")
            sendMetroCommand("w", to: project)
        case "clear":
            project.addInfoLog("🧹 캐시 및 로그 정리...")
            sendMetroCommand("c", to: project)
        case "send":
            project.addInfoLog("📤 Expo Go로 앱 전송...")
            sendMetroCommand("s", to: project)
        case "tunnel":
            project.addInfoLog("🌐 터널 모드로 연결...")
            sendMetroCommand("t", to: project)
        case "lan":
            project.addInfoLog("🏠 LAN 모드로 연결...")
            sendMetroCommand("l", to: project)
        case "localhost":
            project.addInfoLog("🏠 localhost 모드로 연결...")
            sendMetroCommand("o", to: project)
        case "url":
            project.addInfoLog("🔗 URL 정보 표시...")
            sendMetroCommand("u", to: project)
        case "help":
            project.addInfoLog("❓ 도움말 표시...")
            sendMetroCommand("h", to: project)
        case "version":
            project.addInfoLog("📋 버전 정보 표시...")
            sendMetroCommand("v", to: project)
        case "quit", "exit":
            project.addInfoLog("👋 Expo 서버 종료...")
            sendMetroCommand("q", to: project)
        default:
            project.addWarningLog("알 수 없는 명령: \(command)")
        }
    }
    
    private func sendMetroCommand(_ command: String, to project: MetroProject) {
        guard let process = project.process else {
            project.addErrorLog("Metro 프로세스가 없습니다.")
            return
        }
        
        // Metro 프로세스에 명령 전송
        if let inputPipe = process.standardInput as? Pipe {
            let commandData = (command + "\n").data(using: .utf8)
            inputPipe.fileHandleForWriting.write(commandData ?? Data())
        }
    }
    
    // MARK: - Node.js 경로 찾기
    private func getNodePath() -> String {
        // 일반적인 Node.js 설치 경로들 확인
        let possiblePaths = [
            "/Users/ethanchoi/.nvm/versions/node/v20.11.0/bin/node",  // NVM 설치
            "/usr/local/bin/node",  // Homebrew 설치
            "/opt/homebrew/bin/node",  // Apple Silicon Homebrew
            "/usr/bin/node"  // 시스템 설치
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // PATH에서 찾기
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["node"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            NSLog("DEBUG: which node 실패: \(error)")
        }
        
        // 기본값
        return "node"
    }
    
    private func startExternalProcessMonitoring(for project: MetroProject, pid: Int) {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak project] timer in
            guard let self = self, let project = project else {
                timer.invalidate()
                return
            }
            
            // 프로세스가 여전히 실행 중인지 확인
            if !self.isExternalProcessStillRunning(project) {
                project.addWarningLog("외부 Metro 프로세스가 종료되었습니다.")
                timer.invalidate()
                return
            }
            
            // 간단한 상태 업데이트
            project.addInfoLog("📱 외부 Metro 서버 실행 중 (포트: \(project.port))")
        }
    }
    
    func detachExternalLogs(for project: MetroProject) {
        if let task = externalLogTasks.removeValue(forKey: project.id) {
            task.terminate()
            project.addInfoLog("🧪 외부 로그 스트림 중지")
        }
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
    
    // 명령어에서 프로젝트 이름 추출
    private func extractProjectNameFromCommand(_ command: String) -> String {
        // 명령어에서 프로젝트 경로 추출 시도
        if let projectPath = extractProjectPathFromCommand(command) {
            // 경로에서 프로젝트 이름 추출
            let components = projectPath.components(separatedBy: "/")
            if let lastComponent = components.last, !lastComponent.isEmpty {
                // 특수한 경우 처리
                if lastComponent == "node_modules" && components.count > 1 {
                    return components[components.count - 2]
                }
                return lastComponent
            }
        }
        
        // 명령어에서 직접 프로젝트 이름 패턴 찾기
        let patterns = [
            "react-native start",
            "expo start",
            "metro start"
        ]
        
        for pattern in patterns {
            if command.contains(pattern) {
                // 패턴 앞뒤의 텍스트에서 프로젝트 이름 추출 시도
                if let range = command.range(of: pattern) {
                    let beforePattern = String(command[..<range.lowerBound])
                    let afterPattern = String(command[range.upperBound...])
                    
                    // 경로에서 프로젝트 이름 추출
                    let allText = beforePattern + afterPattern
                    let pathComponents = allText.components(separatedBy: "/")
                    for component in pathComponents.reversed() {
                        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !trimmed.contains("node") && !trimmed.contains("npx") {
                            return trimmed
                        }
                    }
                }
            }
        }
        
        return ""
    }
    
    // 프로젝트 타입 결정
    private func determineProjectType(_ projectPath: String) -> ProjectType {
        // 1. 사용자 설정 우선 확인
        if let userProjectType = getUserProjectType(path: projectPath) {
            Logger.debug("determineProjectType - 사용자 설정 프로젝트 타입 사용: \(projectPath) -> \(userProjectType.rawValue)")
            return userProjectType
        }
        
        // 2. 체크 파일 우선 적용
        if let forcedType = readProjectTypeMarker(at: projectPath) {
            Logger.debug("determineProjectType - 체크 파일 프로젝트 타입 사용: \(projectPath) -> \(forcedType.rawValue)")
            return forcedType
        }

        // 3. Expo 징후를 최우선으로 판단 (앱이 bare/native 디렉토리를 포함해도 Expo 우선)
        if isExpoProject(at: projectPath) {
            Logger.debug("determineProjectType - 자동 감지 Expo 프로젝트: \(projectPath)")
            return .expo
        }

        // 4. 그 외에는 CLI 구성 파일 존재 여부로 판단
        let fileManager = FileManager.default
        let cliConfigPaths = [
            "\(projectPath)/react-native.config.js",
            "\(projectPath)/metro.config.js",
            "\(projectPath)/android/build.gradle"
        ]
        for path in cliConfigPaths {
            if fileManager.fileExists(atPath: path) {
                Logger.debug("determineProjectType - 자동 감지 React Native CLI 프로젝트: \(projectPath)")
                return .reactNativeCLI
            }
        }

        // 5. 기본값
        Logger.debug("determineProjectType - 기본값 React Native CLI: \(projectPath)")
        return .reactNativeCLI
    }

    // 체크 파일(.metrotype)에서 타입 강제 지정 읽기
    private func readProjectTypeMarker(at path: String) -> ProjectType? {
        let markerPath = "\(path)/\(projectTypeMarkerFilename)"
        guard FileManager.default.fileExists(atPath: markerPath) else { return nil }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: markerPath))
            guard var text = String(data: data, encoding: .utf8) else { return nil }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch text {
            case "expo":
                return .expo
            case "cli", "react-native", "react-native-cli":
                return .reactNativeCLI
            default:
                return nil
            }
        } catch {
            Logger.error("체크 파일 읽기 실패: \\(error.localizedDescription)")
            return nil
        }
    }

    // 체크 파일(.metrotype) 쓰기/업데이트
    private func writeProjectTypeMarker(at path: String, type: ProjectType) {
        let markerPath = "\(path)/\(projectTypeMarkerFilename)"
        let content = (type == .expo) ? "expo\n" : "cli\n"
        do {
            try content.data(using: .utf8)?.write(to: URL(fileURLWithPath: markerPath))
            Logger.debug("체크 파일 생성/업데이트: \(markerPath) -> \(content.trimmingCharacters(in: .whitespacesAndNewlines))")
        } catch {
            Logger.error("체크 파일 쓰기 실패: \(error.localizedDescription)")
        }
    }
}