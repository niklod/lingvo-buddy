import AppKit

/// The "Aa" menu-bar glyph in a rounded translucent box.
enum StatusGlyph {
    private static let size = NSSize(width: 24, height: 18)
    private static let boxAlpha: CGFloat = 0.3

    @MainActor
    static func image() -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            let box = NSRect(x: 0.5, y: 1, width: size.width - 1, height: size.height - 2)
            NSColor.black.withAlphaComponent(boxAlpha).setFill()
            NSBezierPath(roundedRect: box, xRadius: 4.5, yRadius: 4.5).fill()
            let text = NSAttributedString(string: "Aa", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.black,
                .kern: -0.3,
            ])
            let textSize = text.size()
            text.draw(at: NSPoint(x: box.midX - textSize.width / 2, y: box.midY - textSize.height / 2))
            return true
        }
        // A template image lets macOS tint the glyph for light, dark and inactive menu bars;
        // the box stays translucent because only alpha is kept.
        image.isTemplate = true
        image.accessibilityDescription = "LingvoBuddy"
        return image
    }
}
