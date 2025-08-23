import SwiftUI
import AppKit

struct ConsoleTextView: NSViewRepresentable {
    @Binding var logs: [String]
    let fontSize: CGFloat
    let onCommand: ((String) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // Configure text view
        textView.isEditable = true  // 편집 가능하게 변경
        textView.isRichText = true
        textView.allowsUndo = false
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.textColor = NSColor.labelColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        
        // 키 입력 처리 설정
        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Update font size
        let newFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = newFont
        
        // 현재 커서 위치 저장
        let currentPosition = textView.selectedRange.location
        
        // Clear existing content
        textView.string = ""
        
        // Add logs with colors
        let textStorage = textView.textStorage!
        
        for log in logs {
            let attributedLog = createAttributedString(for: log, fontSize: fontSize)
            textStorage.append(attributedLog)
            
            // Add newline if not already present
            if !log.hasSuffix("\n") {
                let newline = NSAttributedString(string: "\n", attributes: [
                    .font: newFont,
                    .foregroundColor: NSColor.labelColor
                ])
                textStorage.append(newline)
            }
        }
        
        // Auto-scroll to bottom
        if !logs.isEmpty {
            textView.scrollToEndOfDocument(nil)
        }
        
        // 커서를 맨 끝으로 이동
        let endPosition = textView.string.count
        textView.setSelectedRange(NSRange(location: endPosition, length: 0))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCommand: onCommand)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var textView: NSTextView?
        let onCommand: ((String) -> Void)?
        
        init(onCommand: ((String) -> Void)?) {
            self.onCommand = onCommand
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter 키 입력 처리
                let currentText = textView.string
                let lines = currentText.components(separatedBy: .newlines)
                
                if let lastLine = lines.last, !lastLine.isEmpty {
                    // 마지막 줄이 비어있지 않으면 명령어로 처리
                    let command = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !command.isEmpty {
                        onCommand?(command)
                        
                        // 명령어 실행 후 새 줄 추가
                        DispatchQueue.main.async {
                            textView.string += "\n"
                            let endPosition = textView.string.count
                            textView.setSelectedRange(NSRange(location: endPosition, length: 0))
                        }
                        return true
                    }
                }
            }
            return false
        }
    }
    
    private func createAttributedString(for log: String, fontSize: CGFloat) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        var color = NSColor.labelColor
        var cleanedLog = log
        
        // Remove emoji indicators and determine color
        if log.contains("🔴") || log.contains("ERROR:") || 
           log.contains("error") || log.contains("Error") || 
           log.contains("failed") || log.contains("Failed") || 
           log.contains("실패") || log.contains("❌") || 
           log.hasPrefix("🚫") || log.contains("exception") || 
           log.contains("Exception") {
            color = NSColor.systemRed
            cleanedLog = log.replacingOccurrences(of: "🔴 ", with: "")
        } else if log.contains("🟡") || log.contains("WARNING:") || 
                  log.contains("warning") || log.contains("Warning") || 
                  log.contains("경고") || log.contains("warn") {
            color = NSColor.systemOrange
            cleanedLog = log.replacingOccurrences(of: "🟡 ", with: "")
        } else if log.contains("🟢") || log.contains("SUCCESS:") || 
                  log.contains("success") || log.contains("Success") || 
                  log.contains("성공") || log.contains("완료") ||
                  log.contains("completed") || log.contains("Completed") {
            color = NSColor.systemGreen
            cleanedLog = log.replacingOccurrences(of: "🟢 ", with: "")
        } else if log.contains("🔵") || log.contains("INFO:") || 
                  log.contains("info") || log.contains("Info") {
            color = NSColor.systemBlue
            cleanedLog = log.replacingOccurrences(of: "🔵 ", with: "")
        }
        
        return NSAttributedString(string: cleanedLog, attributes: [
            .font: font,
            .foregroundColor: color
        ])
    }
}

#Preview {
    ConsoleTextView(logs: .constant([
        "🔴 ERROR: This is an error message",
        "🟡 WARNING: This is a warning message", 
        "🟢 SUCCESS: This is a success message",
        "🔵 INFO: This is an info message",
        "Regular log message without color"
    ]), fontSize: 12, onCommand: { command in
        print("Command received: \(command)")
    })
    .frame(height: 200)
}