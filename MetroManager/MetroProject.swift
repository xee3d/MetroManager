
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
    
    // 로그 메모리 관리 설정
    private let maxLogCount: Int = 1000  // 최대 로그 개수
    private let logCleanupThreshold: Int = 1200  // 정리 시작 임계값
    private let logCleanupCount: Int = 200  // 한 번에 정리할 로그 개수
    
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
            
            // 로그 개수가 임계값을 초과하면 자동 정리
            if self.logs.count > self.logCleanupThreshold {
                self.performLogCleanup()
            }
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
    
    // MARK: - 로그 메모리 관리
    
    /// 로그 자동 정리 수행 (오래된 로그부터 삭제)
    private func performLogCleanup() {
        guard logs.count > maxLogCount else { return }
        
        // 오래된 로그부터 삭제 (최신 로그 유지)
        let logsToRemove = logs.count - maxLogCount
        if logsToRemove > 0 {
            logs.removeFirst(logsToRemove)
            
            // 정리 완료 로그 추가
            addInfoLog("🧹 로그 자동 정리 완료 (오래된 \(logsToRemove)개 로그 삭제)")
        }
    }
    
    /// 로그 메모리 사용량 계산 (대략적)
    func getLogMemoryUsage() -> Int {
        return logs.reduce(0) { total, log in
            total + log.message.count + 100 // UUID, Date 등 오버헤드 포함
        }
    }
    
    /// 로그 메모리 사용량을 MB 단위로 반환
    func getLogMemoryUsageMB() -> Double {
        return Double(getLogMemoryUsage()) / (1024 * 1024)
    }
    
    /// 로그 상태 정보 반환
    func getLogStatus() -> String {
        let memoryMB = getLogMemoryUsageMB()
        return "로그: \(logs.count)개, 메모리: \(String(format: "%.2f", memoryMB))MB"
    }
    
    /// 강제 로그 정리 (사용자가 요청한 경우)
    func forceLogCleanup() {
        DispatchQueue.main.async {
            let originalCount = self.logs.count
            self.logs.removeAll { log in
                // 에러 로그는 보존하고, 일반 로그만 정리
                log.type != .error
            }
            
            let removedCount = originalCount - self.logs.count
            if removedCount > 0 {
                self.addInfoLog("🧹 수동 로그 정리 완료 (\(removedCount)개 로그 삭제)")
            } else {
                self.addInfoLog("🧹 정리할 로그가 없습니다")
            }
        }
    }
    
    /// 로그 압축 (중복 로그 제거)
    func compressLogs() {
        DispatchQueue.main.async {
            let originalCount = self.logs.count
            var compressedLogs: [LogEntry] = []
            var lastMessage: String? = nil
            var duplicateCount = 0
            
            for log in self.logs {
                if log.message == lastMessage {
                    duplicateCount += 1
                    // 중복 로그는 카운트만 증가
                } else {
                    // 이전 중복 로그가 있었다면 카운트 정보 추가
                    if duplicateCount > 0, let lastLog = compressedLogs.last {
                        let countMessage = " (동일한 메시지 \(duplicateCount + 1)회 반복)"
                        compressedLogs[compressedLogs.count - 1] = LogEntry(lastLog.message + countMessage, type: lastLog.type)
                    }
                    
                    compressedLogs.append(log)
                    lastMessage = log.message
                    duplicateCount = 0
                }
            }
            
            // 마지막 중복 로그 처리
            if duplicateCount > 0, let lastLog = compressedLogs.last {
                let countMessage = " (동일한 메시지 \(duplicateCount + 1)회 반복)"
                compressedLogs[compressedLogs.count - 1] = LogEntry(lastLog.message + countMessage, type: lastLog.type)
            }
            
            self.logs = compressedLogs
            let removedCount = originalCount - self.logs.count
            
            if removedCount > 0 {
                self.addInfoLog("🗜️ 로그 압축 완료 (\(removedCount)개 중복 로그 제거)")
            } else {
                self.addInfoLog("🗜️ 압축할 중복 로그가 없습니다")
            }
        }
    }
}
