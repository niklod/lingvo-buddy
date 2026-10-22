import AppKit

/// The menu-bar glyph: Kapa's head with the word card on top (the app icon's capybara as a
/// line drawing), with a dot when a card waits.
enum StatusGlyph {
    private static let size = NSSize(width: 23, height: 18)
    /// Kapa is drawn on a 44-unit grid (the "Menu-bar glyph" of the design file), scaled to this side.
    private static let glyphSide: CGFloat = 18
    private static let grid: CGFloat = 44
    private static let line: CGFloat = 3.2
    private static let snoutLine: CGFloat = 2.6
    private static let dotDiameter: CGFloat = 6
    /// The clear ring around the dot keeps it apart from Kapa's ear and card.
    private static let dotRing: CGFloat = 1.2

    @MainActor
    static func image(waiting: Bool = false) -> NSImage {
        // Flipped, so the drawing uses the design file's top-down coordinates.
        let image = NSImage(size: size, flipped: true) { _ in
            drawKapa()
            if waiting {
                drawDot()
            }
            return true
        }
        // A template image lets macOS tint the glyph for light, dark and inactive menu bars.
        image.isTemplate = true
        image.accessibilityDescription = waiting ? "LingvoBuddy, a card is waiting" : "LingvoBuddy"
        return image
    }

    private static func drawKapa() {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        defer { context.restoreGraphicsState() }
        let scale = NSAffineTransform()
        scale.scale(by: glyphSide / grid)
        scale.concat()
        NSColor.black.set()

        let card = NSBezierPath(roundedRect: NSRect(x: 12, y: 3, width: 20, height: 11), xRadius: 2.5, yRadius: 2.5)
        let tilt = NSAffineTransform()
        tilt.translateX(by: 22, yBy: 8.5)
        tilt.rotate(byDegrees: -6)
        tilt.translateX(by: -22, yBy: -8.5)
        card.transform(using: tilt as AffineTransform)
        stroke(card, width: line)

        for x: CGFloat in [10, 34] {
            NSBezierPath(ovalIn: NSRect(x: x - 2.6, y: 14.4, width: 5.2, height: 5.2)).fill()
        }
        stroke(NSBezierPath(roundedRect: NSRect(x: 7, y: 15, width: 30, height: 25), xRadius: 11, yRadius: 11), width: line)
        for x: CGFloat in [14, 25] {
            stroke(closedEye(at: x), width: line)
        }
        stroke(NSBezierPath(roundedRect: NSRect(x: 16, y: 30, width: 12, height: 7), xRadius: 3.5, yRadius: 3.5), width: snoutLine)
    }

    /// A calm, closed eye: a shallow arc that dips in the middle.
    private static func closedEye(at x: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: 25.5))
        path.curve(
            to: NSPoint(x: x + 5, y: 25.5),
            controlPoint1: NSPoint(x: x + 1.67, y: 26.57),
            controlPoint2: NSPoint(x: x + 3.33, y: 26.57)
        )
        return path
    }

    private static func stroke(_ path: NSBezierPath, width: CGFloat) {
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func drawDot() {
        let dot = NSRect(x: size.width - dotDiameter, y: 0, width: dotDiameter, height: dotDiameter)
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: dot.insetBy(dx: -dotRing, dy: -dotRing)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}
