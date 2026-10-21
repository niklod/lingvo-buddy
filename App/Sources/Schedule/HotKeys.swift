import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌥⌘W. A global hotkey needs Command or Control: sandboxed apps on macOS 15
    /// may not register Option-only shortcuts.
    @MainActor
    static let showWordNow = Self("showWordNow", initial: .init(.w, modifiers: [.option, .command]))
}

/// A global hotkey the learner can change in Settings.
struct ConfigurableHotKey {
    let name: KeyboardShortcuts.Name
    let title: String
}

/// Global hotkeys through Carbon `RegisterEventHotKey` (via KeyboardShortcuts):
/// sandbox-safe and needs no Accessibility permission.
@MainActor
enum HotKeys {
    /// The Settings window shows a recorder for each; quick add (⌥⌘L) joins this list.
    static var configurable: [ConfigurableHotKey] {
        [ConfigurableHotKey(name: .showWordNow, title: String(localized: "Show word now"))]
    }

    static func register(showWordNow: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .showWordNow, action: showWordNow)
    }
}
