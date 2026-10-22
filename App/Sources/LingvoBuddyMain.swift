import AppKit

@main
@MainActor
enum LingvoBuddyMain {
    static func main() {
        #if DEBUG
        // AppKit catches an exception on the main thread, logs it as <private>
        // and keeps the app running with nothing on screen. A Debug build crashes
        // instead, so the exception and its stack land on stderr and in a crash report.
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        #endif
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only at launch: no Dock icon, no app menu (LSUIElement also says so).
        // ForegroundWindows switches to a regular app while one of our windows is open.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
