import AppKit

/// The menu-bar glyph: Kapa's head with the word card on top (the app icon's capybara as a
/// line drawing). A dot in the top-right corner means a card waits; an up-arrow in the
/// bottom-right corner means an update needs attention. Both can show together.
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
    /// Kapa's outline ends near 15.8 pt; the arrow's left edge (about 16.6 pt) keeps clear of it.
    private static let arrowX: CGFloat = 19.6
    private static let arrowHalfWidth: CGFloat = 2.2
    private static let arrowTipY: CGFloat = 10.8
    private static let arrowBaseY: CGFloat = 16.8
    private static let arrowLine: CGFloat = 1.5

    @MainActor
    static func image(waiting: Bool = false, updateMark: Bool = false) -> NSImage {
        // Flipped, so the drawing uses the design file's top-down coordinates.
        let image = NSImage(size: size, flipped: true) { _ in
            drawKapa()
            if waiting {
                drawDot()
            }
            if updateMark {
                drawUpdateArrow()
            }
            return true
        }
        // A template image lets macOS tint the glyph for light, dark and inactive menu bars.
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription(waiting: waiting, updateMark: updateMark)
        return image
    }

    private static func accessibilityDescription(waiting: Bool, updateMark: Bool) -> String {
        switch (waiting, updateMark) {
        case (false, false): "LingvoBuddy"
        case (true, false): "LingvoBuddy, a card is waiting"
        case (false, true): "LingvoBuddy, an update needs attention"
        case (true, true): "LingvoBuddy, a card is waiting and an update needs attention"
        }
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

    private static func drawUpdateArrow() {
        NSColor.black.set()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: arrowX, y: arrowBaseY))
        path.line(to: NSPoint(x: arrowX, y: arrowTipY))
        path.move(to: NSPoint(x: arrowX - arrowHalfWidth, y: arrowTipY + arrowHalfWidth))
        path.line(to: NSPoint(x: arrowX, y: arrowTipY))
        path.line(to: NSPoint(x: arrowX + arrowHalfWidth, y: arrowTipY + arrowHalfWidth))
        stroke(path, width: arrowLine)
    }
}
