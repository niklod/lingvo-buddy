import LingvoCore
import SwiftUI

/// Kapa's face: after an answer beside the feedback text of the quiz card,
/// and in the tray header (calm while cards run, asleep while they are held back).
enum KapaMood: Equatable {
    case calm
    case asleep
    case happy
    case learned
    case oops
    /// A correct answer too soon to add a dot: no blame, just "slow down".
    case wait

    init(_ result: AnswerResult) {
        switch result.outcome {
        case .correct where result.isTooSoon: self = .wait
        case .correct: self = result.isLearned ? .learned : .happy
        case .wrong, .dontKnow: self = .oops
        }
    }
}

/// Kapa the capybara with the word card on her head. Drawn in the 1024-unit space of the
/// app icon (`design/icon/kapa-onsen.svg`), cropped to the head and the card.
struct KapaMoodView: View {
    /// The quiz card's size; the tray header passes a smaller height.
    static let cardHeight: CGFloat = 59
    private static let viewBox = CGRect(x: 180, y: 170, width: 664, height: 700)

    let mood: KapaMood
    var height: CGFloat = Self.cardHeight

    var body: some View {
        Canvas { context, size in
            var context = context
            let scale = min(size.width / Self.viewBox.width, size.height / Self.viewBox.height)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -Self.viewBox.minX, y: -Self.viewBox.minY)
            KapaDrawing.head(context)
            switch mood {
            case .calm: KapaDrawing.calm(context)
            case .asleep: KapaDrawing.asleep(context)
            case .happy: KapaDrawing.happy(context)
            case .learned: KapaDrawing.learned(context)
            case .oops: KapaDrawing.oops(context)
            case .wait: KapaDrawing.wait(context)
            }
        }
        .frame(width: (height * Self.viewBox.width / Self.viewBox.height).rounded(), height: height)
        .accessibilityHidden(true)
    }
}

private enum KapaDrawing {
    private typealias Palette = Theme.Kapa

    private struct Confetti {
        let center: CGPoint
        let degrees: Double
        let color: Color
    }

    static func head(_ context: GraphicsContext) {
        context.fill(ellipse(320, 400, 46, 38), with: .color(Palette.ear))
        context.fill(ellipse(704, 400, 46, 38), with: .color(Palette.ear))
        context.fill(ellipse(322, 404, 20, 15), with: .color(Palette.earInner))
        context.fill(ellipse(702, 404, 20, 15), with: .color(Palette.earInner))
        context.fill(Path(roundedRect: CGRect(x: 250, y: 390, width: 524, height: 420), cornerRadius: 175), with: .color(Palette.fur))
        context.stroke(
            quad((310, 470), (512, 405), (714, 470)),
            with: .color(Palette.furHighlight.opacity(0.6)),
            style: line(18)
        )
        context.fill(Path(roundedRect: CGRect(x: 392, y: 600, width: 240, height: 160), cornerRadius: 76), with: .color(Palette.snout))
        context.fill(ellipse(470, 648, 16, 10), with: .color(Palette.nose))
        context.fill(ellipse(554, 648, 16, 10), with: .color(Palette.nose))
    }

    static func calm(_ context: GraphicsContext) {
        context.stroke(quad((366, 548), (398, 568), (430, 548)), with: .color(Palette.eye), style: line(17))
        context.stroke(quad((594, 548), (626, 568), (658, 548)), with: .color(Palette.eye), style: line(17))
        blush(context, radius: 32, opacity: 0.25)
        context.stroke(quad((486, 712), (512, 730), (538, 712)), with: .color(Palette.nose), style: line(11))
        card(context, fill: .white, degrees: -6) { card in
            word(card, color: Theme.Palette.accent)
        }
    }

    /// No card on her head: no cards come while she sleeps.
    static func asleep(_ context: GraphicsContext) {
        var eyes = Path()
        eyes.move(to: CGPoint(x: 366, y: 556))
        eyes.addLine(to: CGPoint(x: 430, y: 556))
        eyes.move(to: CGPoint(x: 594, y: 556))
        eyes.addLine(to: CGPoint(x: 658, y: 556))
        context.stroke(eyes, with: .color(Palette.eye), style: line(15))
        blush(context, radius: 32, opacity: 0.2)
        context.fill(ellipse(512, 716, 13, 10), with: .color(Palette.nose))
        let small = Text(verbatim: "z").font(.system(size: 90, weight: .heavy)).foregroundStyle(Palette.sleep)
        let big = Text(verbatim: "Z").font(.system(size: 120, weight: .heavy)).foregroundStyle(Palette.sleep)
        context.draw(small, at: CGPoint(x: 640, y: 330), anchor: .bottomLeading)
        context.draw(big, at: CGPoint(x: 700, y: 260), anchor: .bottomLeading)
    }

    static func happy(_ context: GraphicsContext) {
        smilingFace(context)
        card(context, fill: .white, degrees: -6) { card in
            word(card, color: Theme.Palette.accent)
        }
        context.fill(sparkle(790, 460, 40), with: .color(Palette.sparkle))
        context.fill(sparkle(232, 498, 28), with: .color(Palette.sparkle))
    }

    static func learned(_ context: GraphicsContext) {
        smilingFace(context)
        card(context, fill: Theme.Palette.success, degrees: -6) { card in
            var check = Path()
            check.move(to: CGPoint(x: 460, y: 322))
            check.addLine(to: CGPoint(x: 500, y: 360))
            check.addLine(to: CGPoint(x: 568, y: 288))
            card.stroke(check, with: .color(.white), style: line(30))
        }
        let confetti = [
            Confetti(center: CGPoint(x: 263, y: 227), degrees: 30, color: Palette.confettiPink),
            Confetti(center: CGPoint(x: 773, y: 257), degrees: -25, color: Theme.Palette.accent),
            Confetti(center: CGPoint(x: 803, y: 427), degrees: 50, color: Palette.sparkle),
            Confetti(center: CGPoint(x: 233, y: 437), degrees: -40, color: Theme.Palette.chipReview),
        ]
        for piece in confetti {
            var paper = context
            paper.translateBy(x: piece.center.x, y: piece.center.y)
            paper.rotate(by: .degrees(piece.degrees))
            paper.fill(Path(roundedRect: CGRect(x: -13, y: -7, width: 26, height: 14), cornerRadius: 4), with: .color(piece.color))
        }
    }

    static func oops(_ context: GraphicsContext) {
        var brows = Path()
        brows.move(to: CGPoint(x: 366, y: 512))
        brows.addLine(to: CGPoint(x: 428, y: 496))
        brows.move(to: CGPoint(x: 596, y: 496))
        brows.addLine(to: CGPoint(x: 658, y: 512))
        context.stroke(brows, with: .color(Palette.earInner), style: line(13))
        for x: CGFloat in [398, 626] {
            context.fill(ellipse(x, 556, 18, 18), with: .color(Palette.eye))
            context.fill(ellipse(x + 6, 550, 6, 6), with: .color(.white))
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: 480, y: 718))
        mouth.addQuadCurve(to: CGPoint(x: 512, y: 718), control: CGPoint(x: 496, y: 706))
        mouth.addQuadCurve(to: CGPoint(x: 544, y: 718), control: CGPoint(x: 528, y: 730))
        context.stroke(mouth, with: .color(Palette.nose), style: line(11))
        card(context, fill: .white, degrees: -14) { card in
            word(card, color: Theme.Palette.wrong)
        }
        var drop = Path()
        drop.move(to: CGPoint(x: 770, y: 430))
        drop.addQuadCurve(to: CGPoint(x: 770, y: 500), control: CGPoint(x: 800, y: 476))
        drop.addQuadCurve(to: CGPoint(x: 770, y: 430), control: CGPoint(x: 740, y: 476))
        context.fill(drop, with: .color(Palette.sweat))
    }

    /// Calm eyes under relaxed lids, a small smile and an hourglass on the card.
    static func wait(_ context: GraphicsContext) {
        context.stroke(quad((366, 552), (398, 566), (430, 552)), with: .color(Palette.eye), style: line(17))
        context.stroke(quad((594, 552), (626, 566), (658, 552)), with: .color(Palette.eye), style: line(17))
        var lids = Path()
        lids.move(to: CGPoint(x: 372, y: 528))
        lids.addLine(to: CGPoint(x: 426, y: 532))
        lids.move(to: CGPoint(x: 598, y: 532))
        lids.addLine(to: CGPoint(x: 652, y: 528))
        context.stroke(lids, with: .color(Palette.earInner), style: line(10))
        blush(context, radius: 32, opacity: 0.25)
        context.stroke(quad((490, 714), (512, 726), (534, 714)), with: .color(Palette.nose), style: line(11))
        card(context, fill: .white, degrees: -6, content: hourglass)
    }

    private static func hourglass(_ context: GraphicsContext) {
        var caps = Path()
        caps.move(to: CGPoint(x: 478, y: 266))
        caps.addLine(to: CGPoint(x: 546, y: 266))
        caps.move(to: CGPoint(x: 478, y: 374))
        caps.addLine(to: CGPoint(x: 546, y: 374))
        context.stroke(caps, with: .color(Theme.Palette.accent), style: line(12))
        let glass = polygon([(486, 268), (538, 268), (512, 320), (538, 372), (486, 372), (512, 320)])
        context.stroke(glass, with: .color(Theme.Palette.accent), style: line(11))
        context.fill(polygon([(494, 364), (530, 364), (512, 338)]), with: .color(Palette.sand))
        context.fill(polygon([(500, 288), (524, 288), (512, 306)]), with: .color(Palette.sand.opacity(0.6)))
    }

    /// Eyes closed in a smile, blushing cheeks and an open mouth: the happy and learned face.
    private static func smilingFace(_ context: GraphicsContext) {
        context.stroke(quad((366, 562), (398, 524), (430, 562)), with: .color(Palette.eye), style: line(17))
        context.stroke(quad((594, 562), (626, 524), (658, 562)), with: .color(Palette.eye), style: line(17))
        blush(context, radius: 36, opacity: 0.38)
        var mouth = quad((474, 700), (512, 760), (550, 700))
        mouth.closeSubpath()
        context.fill(mouth, with: .color(Palette.mouth))
        context.stroke(mouth, with: .color(Palette.mouth), style: line(8))
    }

    private static func blush(_ context: GraphicsContext, radius: CGFloat, opacity: Double) {
        context.fill(ellipse(350, 630, radius, radius), with: .color(Palette.blush.opacity(opacity)))
        context.fill(ellipse(674, 630, radius, radius), with: .color(Palette.blush.opacity(opacity)))
    }

    /// The word card on Kapa's head, tilted around its centre.
    private static func card(
        _ context: GraphicsContext,
        fill: Color,
        degrees: Double,
        content: (GraphicsContext) -> Void
    ) {
        var card = context
        card.translateBy(x: 512, y: 320)
        card.rotate(by: .degrees(degrees))
        card.translateBy(x: -512, y: -320)
        card.fill(Path(roundedRect: CGRect(x: 366, y: 240, width: 292, height: 160), cornerRadius: 26), with: .color(fill))
        content(card)
    }

    private static func word(_ context: GraphicsContext, color: Color) {
        let text = Text(verbatim: "Aa").font(.system(size: 112, weight: .heavy)).foregroundStyle(color)
        context.draw(text, at: CGPoint(x: 512, y: 322), anchor: .center)
    }

    /// A four-pointed star.
    private static func sparkle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
        let bend = radius * 0.2
        var path = Path()
        path.move(to: CGPoint(x: x, y: y - radius))
        path.addQuadCurve(to: CGPoint(x: x + radius, y: y), control: CGPoint(x: x + bend, y: y - bend))
        path.addQuadCurve(to: CGPoint(x: x, y: y + radius), control: CGPoint(x: x + bend, y: y + bend))
        path.addQuadCurve(to: CGPoint(x: x - radius, y: y), control: CGPoint(x: x - bend, y: y + bend))
        path.addQuadCurve(to: CGPoint(x: x, y: y - radius), control: CGPoint(x: x - bend, y: y - bend))
        return path
    }

    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ radiusX: CGFloat, _ radiusY: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - radiusX, y: y - radiusY, width: radiusX * 2, height: radiusY * 2))
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    private static func quad(_ start: (CGFloat, CGFloat), _ control: (CGFloat, CGFloat), _ end: (CGFloat, CGFloat)) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: start.0, y: start.1))
        path.addQuadCurve(to: CGPoint(x: end.0, y: end.1), control: CGPoint(x: control.0, y: control.1))
        return path
    }

    private static func line(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}
