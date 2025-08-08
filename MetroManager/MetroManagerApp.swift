import SwiftUI

@main
struct MetroManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
    }
}
