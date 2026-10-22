import AppKit
import LingvoCore
import SwiftUI

enum CardCloseAction: Equatable {
    /// "Next ↵" (or Enter) after an answer.
    case next
    /// "Later": the same word comes back in 5 min.
    case later
    /// "×" or Esc on an unanswered card: skip with no penalty.
    case skip
}

struct CardPanelEvents {
    /// The learner gave the card focus or answered it.
    var engaged: () -> Void = {}
    var closed: (Card, CardCloseAction) -> Void = { _, _ in }
}

/// Shows one quiz card under the status item and reports how the learner closed it.
@MainActor
final class CardPanelController {
    private static let appearDuration: TimeInterval = 0.15
    private static let slideDistance: CGFloat = 6

    private let tutor: Tutor
    private let errors: ErrorPresenter
    var events = CardPanelEvents()
    private var panel: CardPanel?
    private var session: CardSession?

    init(tutor: Tutor, errors: ErrorPresenter) {
        self.tutor = tutor
        self.errors = errors
    }

    var isShowing: Bool { panel?.isVisible == true }
    var isAnswered: Bool { session?.state.isAnswered == true }

    /// `focused` makes the card key at once (hotkey, menu, icon click);
    /// a timed card appears without taking keyboard focus.
    func show(_ card: Card, under anchor: NSStatusBarButton?, focused: Bool) {
        dismiss()
        let session = CardSession(card: card, tutor: tutor) { [errors] error in errors.show(error) }
        let panel = CardPanel()
        panel.setContent(CardSessionView(session: session, actions: actions(for: session)))
        panel.onKey = { [weak self] command in self?.handle(command) ?? false }
        panel.onBecameKey = { [weak self] in self?.events.engaged() }
        self.session = session
        self.panel = panel
        present(panel, at: CardPlacement.origin(for: panel.frame.size, under: anchor), focused: focused)
    }

    func focus() {
        panel?.makeKeyAndOrderFront(nil)
    }

    /// Removes the card with no close action (auto-close, replacement).
    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        session = nil
    }

    private func present(_ panel: CardPanel, at origin: NSPoint, focused: Bool) {
        let target = NSRect(origin: origin, size: panel.frame.size)
        let slide = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : Self.slideDistance
        panel.setFrame(target.offsetBy(dx: 0, dy: slide), display: false)
        panel.alphaValue = 0
        if focused {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.appearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
    }

    private func actions(for session: CardSession) -> QuizCardActions {
        QuizCardActions(
            pick: { [weak self] index in self?.answer { session.pick(index) } },
            dontKnow: { [weak self] in self?.answer { session.dontKnow() } },
            next: { [weak self] in self?.finish(.next) },
            later: { [weak self] in self?.finish(.later) },
            close: { [weak self] in self?.finish(.skip) }
        )
    }

    private func answer(_ submit: () -> Void) {
        submit()
        if session?.state.isAnswered == true {
            events.engaged()
        }
    }

    private func handle(_ command: CardKeyCommand) -> Bool {
        guard let session else { return false }
        switch command {
        case .pick(let index):
            guard session.state.card.options.indices.contains(index) else { return false }
            answer { session.pick(index) }
        case .next:
            // Unanswered, Enter does nothing; it still must not reach a focused option.
            if session.state.isAnswered { finish(.next) }
        case .close:
            finish(.skip)
        }
        return true
    }

    /// An answered card has nothing left to postpone or skip, so every close is "Next".
    private func finish(_ action: CardCloseAction) {
        guard let session else { return }
        let card = session.state.card
        let effective = session.state.isAnswered ? .next : action
        dismiss()
        events.closed(card, effective)
    }
}

/// Where the card hangs: 8 pt under the menu bar, its right edge about 56 pt
/// right of the icon centre (design).
@MainActor
enum CardPlacement {
    private static let rightOverhang: CGFloat = 56

    static func origin(for size: NSSize, under anchor: NSStatusBarButton?) -> NSPoint {
        let insets = Theme.CardShadow.insets
        guard let button = anchor, let window = button.window, let screen = window.screen,
              screen.frame.intersects(window.frame), window.frame.height > 0 else {
            // The icon can be hidden (crowded or auto-hidden menu bar): use the top-right corner.
            guard let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return .zero }
            return NSPoint(x: visible.maxX - size.width, y: visible.maxY - size.height)
        }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let cardRight = buttonFrame.midX + rightOverhang
        let proposedX = cardRight + insets.trailing - size.width
        let x = min(max(proposedX, visible.minX), visible.maxX - size.width)
        return NSPoint(x: x, y: buttonFrame.minY - size.height)
    }
}

private struct CardSessionView: View {
    let session: CardSession
    let actions: QuizCardActions

    var body: some View {
        QuizCardView(state: session.state, actions: actions)
    }
}
