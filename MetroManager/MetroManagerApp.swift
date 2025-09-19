import SwiftUI
import AppKit

@main
struct MetroManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var singleInstanceLock: FileHandle?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 앱 활성화 및 창 표시 강제
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 지연 후 창 표시 강제
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApplication.shared.windows {
                window.makeKeyAndOrderFront(nil)
                window.center()
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 단일 인스턴스 락 해제
        singleInstanceLock?.closeFile()
        
        // 임시 파일 삭제
        let lockFileURL = getLockFileURL()
        try? FileManager.default.removeItem(at: lockFileURL)
    }
    
    private func checkSingleInstance() -> Bool {
        let lockFileURL = getLockFileURL()
        
        // 락 파일 생성 시도
        do {
            let lockData = "MetroManager".data(using: .utf8)!
            try lockData.write(to: lockFileURL)
            singleInstanceLock = try FileHandle(forWritingTo: lockFileURL)
            
            // 파일 핸들을 유지하여 다른 프로세스가 파일을 삭제하지 못하도록 함
            return true
        } catch {
            // 이미 다른 인스턴스가 실행 중
            showAlreadyRunningAlert()
            return false
        }
    }
    
    private func getLockFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("MetroManager.lock")
    }
    
    private func showAlreadyRunningAlert() {
        let alert = NSAlert()
        alert.messageText = "MetroManager가 이미 실행 중입니다"
        alert.informativeText = "MetroManager는 한 번에 하나의 인스턴스만 실행할 수 있습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}
