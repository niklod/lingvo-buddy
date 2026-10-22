import AppKit

/// An accessory (menu-bar) app may not take activation on macOS 14+, so a
/// window would open inactive behind other apps. A regular app may: the Dock
/// icon shows only while one of our titled windows (Settings, Dictionary,
/// onboarding) is open or minimized.
@MainActor
enum ForegroundWindows {
    static func show(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // Activation is a request macOS may refuse (an app launched from the
        // background, at login); the window must still come in front of others.
        window.orderFrontRegardless()
    }

    /// Call from `windowWillClose`: the closing window still counts as visible.
    /// A minimized window is not visible, but its only way back is the Dock tile.
    static func willClose(_ window: NSWindow) {
        let othersOpen = NSApp.windows.contains { other in
            other !== window && (other.isVisible || other.isMiniaturized) && other.styleMask.contains(.titled)
        }
        if !othersOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
