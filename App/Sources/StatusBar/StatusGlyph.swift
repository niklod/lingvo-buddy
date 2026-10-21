import AppKit

/// The "Aa" menu-bar glyph in a rounded translucent box, with a dot when a card waits.
enum StatusGlyph {
    private static let size = NSSize(width: 24, height: 18)
    private static let boxAlpha: CGFloat = 0.3
    private static let dotDiameter: CGFloat = 6
    /// The clear ring around the dot keeps it readable on top of the box edge.
    private static let dotRing: CGFloat = 1.2

    @MainActor
    static func image(waiting: Bool = false) -> NSImage {
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
            if waiting {
                drawDot()
            }
            return true
        }
        // A template image lets macOS tint the glyph for light, dark and inactive menu bars;
        // the box stays translucent because only alpha is kept.
        image.isTemplate = true
        image.accessibilityDescription = waiting ? "LingvoBuddy, a card is waiting" : "LingvoBuddy"
        return image
    }

    private static func drawDot() {
        let dot = NSRect(
            x: size.width - dotDiameter,
            y: size.height - dotDiameter,
            width: dotDiameter,
            height: dotDiameter
        )
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: dot.insetBy(dx: -dotRing, dy: -dotRing)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}
