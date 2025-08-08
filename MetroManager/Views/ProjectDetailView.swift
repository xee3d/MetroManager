
import SwiftUI
import Foundation

// MARK: - Project Detail View
struct ProjectDetailView: View {
    @ObservedObject var project: MetroProject
    @ObservedObject var metroManager: MetroManager
    
    var body: some View {
        VStack(spacing: 15) {
            // 제어 패널
            HStack {
                Text(project.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if project.isRunning {
                            if project.isExternalProcess {
                                metroManager.stopExternalMetroProcess(for: project)
                            } else {
                                metroManager.stopMetro(for: project)
                            }
                        } else if !project.isExternalProcess {
                            metroManager.startMetro(for: project)
                        }
                    }) {
                        if project.isRunning {
                            Label(project.isExternalProcess ? "외부 중지" : "중지", systemImage: "stop.fill")
                        } else if project.isExternalProcess {
                            Label("외부 프로세스", systemImage: "externaldrive.connected")
                        } else {
                            Label("시작", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(project.isRunning ? .red : (project.isExternalProcess ? .purple : .green))
                    .disabled(project.status == .starting || (project.isExternalProcess && !project.isRunning))
                    
                    Button(action: {
                        metroManager.clearLogs(for: project)
                    }) {
                        Label("로그 삭제", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        openInTerminal(path: project.path)
                    }) {
                        Label("터미널", systemImage: "terminal")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        openInXcode(path: project.path)
                    }) {
                        Label("Xcode", systemImage: "hammer")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            .padding()
            
            // 프로젝트 정보
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("프로젝트 타입")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(project.projectType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(project.projectType == .expo ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                            .foregroundColor(project.projectType == .expo ? .blue : .orange)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("포트")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(project.port)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if project.isExternalProcess {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("프로세스 유형")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("외부 프로세스")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                        }
                    }
                    
                    if let pid = project.externalProcessId {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pid)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("경로")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(project.path)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Divider()
            
            // 콘솔 로그
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Text("콘솔 출력")
                        .font(.headline)
                    
                    Spacer()
                    
                    // 텍스트 크기 조절
                    HStack(spacing: 4) {
                        Text("크기:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            if metroManager.consoleTextSize > 8 {
                                metroManager.consoleTextSize -= 1
                                metroManager.saveSettings()
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .disabled(metroManager.consoleTextSize <= 8)
                        
                        Text("\(Int(metroManager.consoleTextSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(minWidth: 20)
                        
                        Button(action: {
                            if metroManager.consoleTextSize < 20 {
                                metroManager.consoleTextSize += 1
                                metroManager.saveSettings()
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .disabled(metroManager.consoleTextSize >= 20)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button(action: {
                        let allLogs = project.logs.joined(separator: "\n")
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(allLogs, forType: .string)
                    }) {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(project.logs.isEmpty)
                    
                    if project.isExternalProcess && project.status == .running {
                        Button(action: {
                            metroManager.fetchExternalMetroLogs(for: project)
                        }) {
                            Label("외부 로그", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                }
                .padding(.horizontal)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(project.logs.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(size: metroManager.consoleTextSize, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.05))
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .textSelection(.enabled)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .textSelection(.enabled)
                    .onChange(of: project.logs.count) { _ in
                        if !project.logs.isEmpty {
                            proxy.scrollTo(project.logs.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
            
            Spacer()
        }
        
        if let errorMessage = metroManager.errorMessage, metroManager.showingErrorAlert == false {
            Text("오류: \(errorMessage)")
                .font(.caption)
                .foregroundColor(.red)
                .padding([.horizontal, .bottom])
                .textSelection(.enabled)
        }
    }
    
    private func openInXcode(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            metroManager.errorMessage = "유효하지 않은 경로입니다: \(path)"
            metroManager.showingErrorAlert = true
            return
        }
        
        // Xcode 프로젝트 파일 찾기
        let xcodeProjectExtensions = [".xcodeproj", ".xcworkspace"]
        var xcodeProjectPath: String?
        
        for ext in xcodeProjectExtensions {
            let projectPath = "\(path)/\(URL(fileURLWithPath: path).lastPathComponent)\(ext)"
            if FileManager.default.fileExists(atPath: projectPath) {
                xcodeProjectPath = projectPath
                break
            }
        }
        
        // Xcode 프로젝트가 없으면 폴더 자체를 열기
        let targetPath = xcodeProjectPath ?? path
        let targetURL = URL(fileURLWithPath: targetPath)
        
        // Xcode로 열기
        let xcodeURL = URL(fileURLWithPath: "/Applications/Xcode.app")
        
        NSWorkspace.shared.open([targetURL], 
                                withApplicationAt: xcodeURL, 
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.metroManager.errorMessage = "Xcode 열기 오류: \(error.localizedDescription)"
                    self.metroManager.showingErrorAlert = true
                }
            } else {
                DispatchQueue.main.async {
                    self.metroManager.errorMessage = "Xcode에서 프로젝트를 열었습니다: \(URL(fileURLWithPath: targetPath).lastPathComponent)"
                    self.metroManager.showingErrorAlert = true
                }
            }
        }
    }
    
    private func openInTerminal(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            metroManager.errorMessage = "유효하지 않은 경로입니다: \(path)"
            metroManager.showingErrorAlert = true
            return
        }
        
        // AppleScript를 사용해서 기존 터미널 창에 명령어 전송
        let script = """
        tell application "Terminal"
            if (count of windows) > 0 then
                -- 기존 터미널 창이 있으면 새 탭 생성
                tell application "System Events" to tell process "Terminal" to keystroke "t" using command down
                delay 0.5
                -- 새 탭에서 프로젝트 디렉토리로 이동
                do script "cd '\(path)'" in selected tab of front window
            else
                -- 터미널 창이 없으면 새 창 생성
                do script "cd '\(path)'"
            end if
            activate
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        do {
            try task.run()
        } catch {
            // AppleScript 실패 시 기존 방식으로 폴백
            let pathURL = URL(fileURLWithPath: path)
            let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            
            NSWorkspace.shared.open([pathURL], 
                                    withApplicationAt: terminalURL, 
                                    configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.metroManager.errorMessage = "터미널 열기 오류: \(error.localizedDescription)"
                        self.metroManager.showingErrorAlert = true
                    }
                }
            }
        }
    }
}

struct ProjectDetailView_Previews: PreviewProvider {
    static var previewMetroManager: MetroManager = {
        let manager = MetroManager()
        manager.addProject(name: "Sample Project 1", path: "/Users/user/Projects/SampleProject1")
        manager.addProject(name: "Sample Project 2", path: "/Users/user/Projects/SampleProject2")
        return manager
    }()

    static var previewProjectRunning: MetroProject = {
        let project = previewMetroManager.projects[0]
        project.status = .running
        project.isRunning = true
        project.logs.append("Running log line 1")
        project.logs.append("Running log line 2")
        project.logs.append("Running log line 3")
        return project
    }()

    static var previewProjectStopped: MetroProject = {
        let project = previewMetroManager.projects[1]
        project.status = .stopped
        project.isRunning = false
        project.logs.append("Stopped log line 1")
        return project
    }()

    static var previews: some View {
        Group {
            ProjectDetailView(project: previewProjectRunning, metroManager: previewMetroManager)
                .previewDisplayName("Running Project Detail")

            ProjectDetailView(project: previewProjectStopped, metroManager: previewMetroManager)
                .previewDisplayName("Stopped Project Detail")
        }
        .frame(width: 700, height: 500)
    }
}
