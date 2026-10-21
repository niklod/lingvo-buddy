import AppKit
import LingvoCore
import SwiftUI

/// Shows the quiz card under the status item and closes it on "Next", "Later" or "×".
@MainActor
final class CardPanelController {
    /// The design hangs the card 8 pt under the menu bar, its right edge
    /// about 56 pt right of the icon centre.
    private static let rightOverhang: CGFloat = 56

    private let tutor: Tutor
    private let errors: ErrorPresenter
    private var panel: CardPanel?
    private var session: CardSession?

    init(tutor: Tutor, errors: ErrorPresenter) {
        self.tutor = tutor
        self.errors = errors
    }

    var isShowing: Bool { panel?.isVisible == true }

    func showNextCard(under anchor: NSStatusBarButton?) {
        do {
            switch try tutor.nextCard() {
            case .card(let card):
                show(card, under: anchor)
            case .noCard(let reason):
                errors.inform(Self.message(for: reason))
            }
        } catch {
            errors.show(error)
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        session = nil
    }

    private func show(_ card: Card, under anchor: NSStatusBarButton?) {
        close()
        let session = CardSession(card: card, tutor: tutor) { [errors] error in errors.show(error) }
        let panel = CardPanel()
        panel.setContent(CardSessionView(session: session, actions: actions(for: session)))
        panel.setFrameOrigin(origin(for: panel.frame.size, under: anchor))
        panel.orderFrontRegardless()
        self.session = session
        self.panel = panel
    }

    private func actions(for session: CardSession) -> QuizCardActions {
        QuizCardActions(
            pick: { [weak session] index in session?.pick(index) },
            dontKnow: { [weak session] in session?.dontKnow() },
            next: { [weak self] in self?.close() },
            // Re-show in 5 min and skip rules arrive with the timed-cards slice.
            later: { [weak self] in self?.close() },
            close: { [weak self] in self?.close() }
        )
    }

    private func origin(for size: NSSize, under anchor: NSStatusBarButton?) -> NSPoint {
        let insets = Theme.CardShadow.insets
        guard let button = anchor, let window = button.window, let screen = window.screen,
              screen.frame.intersects(window.frame), window.frame.height > 0 else {
            // The icon can be hidden (crowded or auto-hidden menu bar): use the top-right corner.
            let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            return NSPoint(x: visible.maxX - size.width, y: visible.maxY - size.height)
        }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let cardRight = buttonFrame.midX + Self.rightOverhang
        let proposedX = cardRight + insets.trailing - size.width
        let x = min(max(proposedX, visible.minX), visible.maxX - size.width)
        return NSPoint(x: x, y: buttonFrame.minY - size.height)
    }

    private static func message(for reason: NoCardReason) -> String {
        switch reason {
        case .noWordsAvailable:
            String(localized: "There are no words to practice right now.")
        }
    }
}

private struct CardSessionView: View {
    let session: CardSession
    let actions: QuizCardActions

    var body: some View {
        QuizCardView(state: session.state, actions: actions)
    }
}
