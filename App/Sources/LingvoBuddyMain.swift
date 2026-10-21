import AppKit

@main
@MainActor
enum LingvoBuddyMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only: no Dock icon, no app menu (LSUIElement also says so).
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
