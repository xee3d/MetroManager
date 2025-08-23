
import SwiftUI
import Foundation

// MARK: - 모델
enum ProjectType: String, CaseIterable {
    case expo = "Expo"
    case reactNativeCLI = "React Native CLI"
    
    var description: String {
        return self.rawValue
    }
}

enum LogType {
    case info
    case success
    case warning
    case error
    
    var color: Color {
        switch self {
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let type: LogType
    let timestamp: Date
    
    init(_ message: String, type: LogType = .info) {
        self.message = message
        self.type = type
        self.timestamp = Date()
    }
}

class MetroProject: ObservableObject, Identifiable, Hashable {
    static func == (lhs: MetroProject, rhs: MetroProject) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id = UUID()
    @Published var name: String
    @Published var path: String
    @Published var port: Int
    @Published var projectType: ProjectType = .expo
    @Published var isRunning: Bool = false
    @Published var logs: [LogEntry] = []
    @Published var status: MetroStatus = .stopped
    @Published var retryCount: Int = 0
    @Published var shouldRetry: Bool = true
    @Published var isExternalProcess: Bool = false
    @Published var externalProcessId: Int? = nil
    @Published var lastStatusCheck: Date = Date()
    @Published var isInteractiveMode: Bool = true  // 대화형 모드 기본 활성화
    
    var process: Process?
    
    enum MetroStatus {
        case stopped
        case starting
        case running
        case error
        
        var color: Color {
            switch self {
            case .stopped: return .gray
            case .starting: return .yellow
            case .running: return .green
            case .error: return .red
            }
        }
        
        var text: String {
            switch self {
            case .stopped: return "중지됨"
            case .starting: return "시작 중..."
            case .running: return "실행 중"
            case .error: return "오류"
            }
        }
    }
    
    init(name: String, path: String, port: Int, projectType: ProjectType = .expo) {
        self.name = name
        self.path = path
        self.port = port
        self.projectType = projectType
    }
    
    // 편의 메서드들
    func addLog(_ message: String, type: LogType = .info) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(message, type: type))
        }
    }
    
    func addInfoLog(_ message: String) {
        addLog(message, type: .info)
    }
    
    func addSuccessLog(_ message: String) {
        addLog(message, type: .success)
    }
    
    func addWarningLog(_ message: String) {
        addLog(message, type: .warning)
    }
    
    func addErrorLog(_ message: String) {
        addLog(message, type: .error)
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}
