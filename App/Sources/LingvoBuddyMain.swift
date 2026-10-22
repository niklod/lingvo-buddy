import AppKit

@main
@MainActor
enum LingvoBuddyMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only at launch: no Dock icon, no app menu (LSUIElement also says so).
        // ForegroundWindows switches to a regular app while one of our windows is open.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
