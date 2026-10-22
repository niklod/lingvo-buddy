import AppKit
import SwiftUI

extension NSWindow {
    /// The dark titled window that Settings, the Dictionary and onboarding share:
    /// one place for the look, so the three windows cannot drift apart.
    static func themed(
        _ root: some View,
        title: String,
        style: NSWindow.StyleMask,
        sizing: NSHostingSizingOptions = [.preferredContentSize],
        hidesTitle: Bool = false,
        contentSize: CGSize? = nil,
        autosaveName: String? = nil
    ) -> NSWindow {
        let host = NSHostingController(rootView: root)
        host.sizingOptions = sizing
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.styleMask = style
        window.titlebarAppearsTransparent = true
        if hidesTitle {
            // The view draws its own heading; the title stays for VoiceOver and Mission Control.
            window.titleVisibility = .hidden
        }
        window.backgroundColor = NSColor(Theme.Palette.panel)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        if let contentSize {
            window.setContentSize(contentSize)
        }
        window.center()
        if let autosaveName {
            // After center(): a saved frame wins over the centred default.
            window.setFrameAutosaveName(autosaveName)
        }
        return window
    }
}
