
import SwiftUI
import Foundation

// MARK: - Project Detail View
struct ProjectDetailView: View {
    @ObservedObject var project: MetroProject
    @ObservedObject var metroManager: MetroManager
    @State private var unifiedSelectionMode: Bool = false
    @State private var searchQuery: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            // 제목
            HStack {
                Text(project.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // 제어 패널 - 그룹별로 정리
            VStack(spacing: 12) {
                // 기본 제어 버튼들
                HStack(spacing: 12) {
                    Button(action: {
                        if project.isRunning {
                            if project.isExternalProcess {
                                metroManager.stopExternalMetroProcess(for: project)
                                metroManager.detachExternalLogs(for: project)
                            } else {
                                metroManager.stopMetro(for: project)
                            }
                        } else {
                            // 외부 프로세스였더라도 멈춘 상태면 우리 소유로 재시작 허용
                            metroManager.startMetro(for: project)
                            project.isExternalProcess = false
                            project.externalProcessId = nil
                        }
                    }) {
                        if project.isRunning {
                            Label(project.isExternalProcess ? "외부 중지" : "중지", systemImage: "stop.fill")
                        } else {
                            Label("시작", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(project.isRunning ? .red : .green)
                    .disabled(project.status == .starting)
                    .help(project.isRunning ? 
                          (project.isExternalProcess ? "외부 프로세스를 중지합니다" : "Metro를 중지합니다") :
                          (!metroManager.isPortAvailable(project.port) ? 
                           "포트 \(project.port)가 사용 중입니다. 시작하면 기존 프로세스를 자동으로 종료합니다." : 
                           "Metro를 시작합니다"))
                    
                    if project.isExternalProcess && project.isRunning {
                        Button(action: {
                            if metroManager.isAttachingExternalLogs(for: project) {
                                metroManager.detachExternalLogs(for: project)
                            } else {
                                metroManager.attachExternalLogs(for: project)
                            }
                        }) {
                            Label(metroManager.isAttachingExternalLogs(for: project) ? "스트림 중지" : "스트림 연결", systemImage: metroManager.isAttachingExternalLogs(for: project) ? "bolt.slash" : "bolt")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                    
                    Button(action: {
                        openInTerminal(path: project.path)
                    }) {
                        Label("터미널", systemImage: "terminal")
                    }
                    .buttonStyle(.bordered)
                }
                
                // 로그 관리 버튼들
                HStack(spacing: 8) {
                    Text("로그 관리:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        metroManager.clearLogs(for: project)
                    }) {
                        Label("삭제", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: {
                        project.forceLogCleanup()
                    }) {
                        Label("정리", systemImage: "trash.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.small)
                    .help("오래된 로그만 정리 (에러 로그 보존)")
                    
                    Button(action: {
                        project.compressLogs()
                    }) {
                        Label("압축", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)
                    .help("중복 로그 압축")
                }
            }
            .padding(.horizontal)
            
            // 자동 해결 도구 및 실행 버튼 제거됨
            
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
                            HStack(spacing: 4) {
                                Text("외부 프로세스")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(6)
                                
                                // 로그 연결 상태 표시
                                if metroManager.isAttachingExternalLogs(for: project) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .foregroundColor(.green)
                                        .help("로그 스트림 연결됨")
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                        .foregroundColor(.orange)
                                        .help("로그 스트림 연결 안됨")
                                }
                            }
                        }
                    }
                    
                    // 포트 충돌 상태 표시
                    if !metroManager.isPortAvailable(project.port) && !project.isRunning {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("포트 상태")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("포트 충돌")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(6)
                            }
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
            
            // 핵심 단축키 - 컴팩트하게 정리
            if project.isRunning {
                VStack(spacing: 8) {
                    HStack {
                        Text("핵심 단축키")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("💡 더 많은 단축키는 키보드로 입력")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 기본 단축키들 - 한 줄로 정리
                    HStack(spacing: 6) {
                        Button(action: {
                            metroManager.handleUserCommand("r", for: project)
                        }) {
                            Text("r")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.small)
                        .help("리로드")
                        
                        Button(action: {
                            metroManager.handleUserCommand("i", for: project)
                        }) {
                            Text("i")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.small)
                        .help("iOS 시뮬레이터")
                        
                        Button(action: {
                            metroManager.handleUserCommand("a", for: project)
                        }) {
                            Text("a")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .controlSize(.small)
                        .help("Android 에뮬레이터")
                        
                        Button(action: {
                            metroManager.handleUserCommand("d", for: project)
                        }) {
                            Text("d")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.small)
                        .help("개발자 메뉴")
                        
                        // Expo 전용 단축키
                        if project.projectType == .expo {
                            Button(action: {
                                metroManager.handleUserCommand("w", for: project)
                            }) {
                                Text("w")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .controlSize(.small)
                            .help("웹")
                            
                            Button(action: {
                                metroManager.handleUserCommand("c", for: project)
                            }) {
                                Text("c")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                            .help("캐시 정리")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
                .padding(.horizontal)
            }
            
            // 콘솔 로그
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Text("콘솔 출력")
                        .font(.headline)
                    
                    // 로그 상태 정보 표시
                    Text(project.getLogStatus())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // 외부 프로세스 로그 연결 버튼
                    if project.isExternalProcess {
                        Button(action: {
                            if metroManager.isAttachingExternalLogs(for: project) {
                                metroManager.detachExternalLogs(for: project)
                            } else {
                                metroManager.attachExternalLogs(for: project)
                            }
                        }) {
                            Label(
                                metroManager.isAttachingExternalLogs(for: project) ? "로그 연결 해제" : "로그 연결",
                                systemImage: metroManager.isAttachingExternalLogs(for: project) ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(metroManager.isAttachingExternalLogs(for: project) ? .red : .green)
                    }
                    
                    // 드래그 복사 모드 토글
                    Button(action: { unifiedSelectionMode.toggle() }) {
                        Label(unifiedSelectionMode ? "드래그 복사 끄기" : "드래그 복사 켜기", systemImage: "text.cursor")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    

                    // 검색창
                    TextField("검색", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .disableAutocorrection(true)
                    
                    
                    
                    Button(action: {
                        let allLogs = project.logs.map { $0.message }.joined(separator: "\n")
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(allLogs, forType: .string)
                    }) {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(project.logs.isEmpty)

                    
                    
                    Button(action: {
                        let errorLogs = project.logs
                            .filter { entry in
                                let m = entry.message
                                return entry.type == .error ||
                                       m.contains("ERROR:") ||
                                       m.contains("error") ||
                                       m.contains("Error") ||
                                       m.contains("failed") ||
                                       m.contains("Failed") ||
                                       m.contains("실패") ||
                                       m.contains("❌") ||
                                       m.hasPrefix("🚫") ||
                                       m.contains("exception") ||
                                       m.contains("Exception")
                            }
                            .map { $0.message }
                            .joined(separator: "\n")
                        
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(errorLogs.isEmpty ? "에러 로그가 없습니다." : errorLogs, forType: .string)
                    }) {
                        Label("에러만 복사", systemImage: "exclamationmark.triangle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(project.logs.isEmpty)
                    
                    
                }
                .padding(.horizontal)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        // 검색 필터 적용된 로그
                        let filteredLogs = project.logs.filter { entry in
                            searchQuery.isEmpty || entry.message.localizedCaseInsensitiveContains(searchQuery)
                        }
                        if unifiedSelectionMode {
                            // 하나의 텍스트 블록으로 표시하여 전체 드래그/복사 가능
                            let combined = buildCombinedAttributedLogs(filtered: filteredLogs)
                            Text(combined)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("combinedText")
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, logEntry in
                                    Text(logEntry.message)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(logEntry.type.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 1)
                                        .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.05))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: project.logs.count) { _ in
                        if !project.logs.isEmpty {
                            if unifiedSelectionMode {
                                proxy.scrollTo("combinedText", anchor: .bottom)
                            } else if searchQuery.isEmpty {
                                proxy.scrollTo(project.logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            setupKeyboardMonitoring()
        }
        
        if let errorMessage = metroManager.errorMessage, metroManager.showingErrorAlert == false {
            Text("오류: \(errorMessage)")
                .font(.caption)
                .foregroundColor(.red)
                .padding([.horizontal, .bottom])
                .textSelection(.enabled)
        }
    }
    
    // MARK: - 키보드 단축키 처리
    private func setupKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleKeyEvent(event)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard project.isRunning else {
            return event
        }
        
        let key = event.charactersIgnoringModifiers?.lowercased()
        
        switch key {
        case "r":
            metroManager.handleUserCommand("r", for: project)
            return nil // 이벤트 소비
        case "i":
            metroManager.handleUserCommand("i", for: project)
            return nil
        case "a":
            metroManager.handleUserCommand("a", for: project)
            return nil
        case "d":
            metroManager.handleUserCommand("d", for: project)
            return nil
        case "j":
            metroManager.handleUserCommand("j", for: project)
            return nil
        case "m":
            metroManager.handleUserCommand("m", for: project)
            return nil
        case "w" where project.projectType == .expo:
            metroManager.handleUserCommand("w", for: project)
            return nil
        case "c" where project.projectType == .expo:
            metroManager.handleUserCommand("c", for: project)
            return nil
        case "s" where project.projectType == .expo:
            metroManager.handleUserCommand("s", for: project)
            return nil
        case "t" where project.projectType == .expo:
            metroManager.handleUserCommand("t", for: project)
            return nil
        case "l" where project.projectType == .expo:
            metroManager.handleUserCommand("l", for: project)
            return nil
        case "o" where project.projectType == .expo:
            metroManager.handleUserCommand("o", for: project)
            return nil
        case "u" where project.projectType == .expo:
            metroManager.handleUserCommand("u", for: project)
            return nil
        case "h" where project.projectType == .expo:
            metroManager.handleUserCommand("h", for: project)
            return nil
        case "v" where project.projectType == .expo:
            metroManager.handleUserCommand("v", for: project)
            return nil
        case "q" where project.projectType == .expo:
            metroManager.handleUserCommand("q", for: project)
            return nil
        default:
            return event // 이벤트 전달
        }
    }
    
    private func parseLogForColor(_ log: String) -> AttributedString {
        // Remove ANSI escape sequences first
        var cleanedLog = log
        
        // Remove ANSI color codes (like [7m, [0m, etc.)
        let ansiPattern = "\\[[0-9;]*m"
        cleanedLog = cleanedLog.replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
        
        // Remove emoji indicators and determine color
        var color = Color.primary
        
        if cleanedLog.contains("🔴") || cleanedLog.contains("ERROR:") || 
           cleanedLog.contains("error") || cleanedLog.contains("Error") || 
           cleanedLog.contains("failed") || cleanedLog.contains("Failed") || 
           cleanedLog.contains("실패") || cleanedLog.contains("❌") || 
           cleanedLog.hasPrefix("🚫") || cleanedLog.contains("exception") || 
           cleanedLog.contains("Exception") {
            color = .red
            cleanedLog = cleanedLog.replacingOccurrences(of: "🔴 ", with: "")
        } else if cleanedLog.contains("🟡") || cleanedLog.contains("WARNING:") || 
                  cleanedLog.contains("warning") || cleanedLog.contains("Warning") || 
                  cleanedLog.contains("경고") || cleanedLog.contains("warn") {
            color = .orange
            cleanedLog = cleanedLog.replacingOccurrences(of: "🟡 ", with: "")
        } else if cleanedLog.contains("🟢") || cleanedLog.contains("SUCCESS:") || 
                  cleanedLog.contains("success") || cleanedLog.contains("Success") || 
                  cleanedLog.contains("성공") || cleanedLog.contains("완료") ||
                  cleanedLog.contains("completed") || cleanedLog.contains("Completed") {
            color = .green
            cleanedLog = cleanedLog.replacingOccurrences(of: "🟢 ", with: "")
        } else if cleanedLog.contains("🔵") || cleanedLog.contains("INFO:") || 
                  cleanedLog.contains("info") || cleanedLog.contains("Info") {
            color = .blue
            cleanedLog = cleanedLog.replacingOccurrences(of: "🔵 ", with: "")
        }
        
        var attributedString = AttributedString(cleanedLog)
        attributedString.foregroundColor = color
        
        return attributedString
    }
    
    private func buildCombinedAttributedLogs(filtered: [LogEntry]? = nil) -> AttributedString {
        let logs = filtered ?? project.logs
        var combined = AttributedString("")
        for (index, entry) in logs.enumerated() {
            var line = AttributedString(entry.message)
            line.foregroundColor = entry.type.color
            combined.append(line)
            if index < logs.count - 1 {
                combined.append(AttributedString("\n"))
            }
        }
        return combined
    }
    
    private func saveLogsToFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "MetroLogs_\(formatter.string(from: Date())).txt"
        let text = project.logs.map { $0.message }.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedFileTypes = ["txt"]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try text.data(using: .utf8)?.write(to: url)
                metroManager.errorMessage = "로그를 저장했습니다: \(url.lastPathComponent)"
                metroManager.showingErrorAlert = true
            } catch {
                metroManager.errorMessage = "로그 저장 실패: \(error.localizedDescription)"
                metroManager.showingErrorAlert = true
            }
        }
    }
    
    private func openInTerminal(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            metroManager.errorMessage = "유효하지 않은 경로입니다: \(path)"
            metroManager.showingErrorAlert = true
            return
        }
        
        // 간단하고 안정적인 방법으로 터미널 열기
        let pathURL = URL(fileURLWithPath: path)
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        
        NSWorkspace.shared.open([pathURL],
                                withApplicationAt: terminalURL,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.metroManager.errorMessage = "터미널 열기 오류: \(error.localizedDescription)"
                    self.metroManager.showingErrorAlert = true
                } else {
                    // 성공 시 팝업을 띄우지 않고 로그만 남깁니다
                    project.addInfoLog("터미널에서 프로젝트를 열었습니다: \(pathURL.lastPathComponent)")
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
        project.addInfoLog("Running log line 1")
        project.addInfoLog("Running log line 2")
        project.addInfoLog("Running log line 3")
        return project
    }()

    static var previewProjectStopped: MetroProject = {
        let project = previewMetroManager.projects[1]
        project.status = .stopped
        project.isRunning = false
        project.addInfoLog("Stopped log line 1")
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
