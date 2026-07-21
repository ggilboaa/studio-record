import SwiftUI

@main
struct StudioRecordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 580)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
