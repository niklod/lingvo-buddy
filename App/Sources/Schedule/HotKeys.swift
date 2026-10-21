import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌥⌘W. A global hotkey needs Command or Control: sandboxed apps on macOS 15
    /// may not register Option-only shortcuts.
    @MainActor
    static let showWordNow = Self("showWordNow", initial: .init(.w, modifiers: [.option, .command]))

    /// ⌥⌘L opens the quick-add panel from any app.
    @MainActor
    static let quickAdd = Self("quickAdd", initial: .init(.l, modifiers: [.option, .command]))
}

/// Global hotkeys through Carbon `RegisterEventHotKey` (via KeyboardShortcuts):
/// sandbox-safe and needs no Accessibility permission.
@MainActor
enum HotKeys {
    static func register(showWordNow: @escaping () -> Void, quickAdd: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .showWordNow, action: showWordNow)
        KeyboardShortcuts.onKeyDown(for: .quickAdd, action: quickAdd)
    }
}
