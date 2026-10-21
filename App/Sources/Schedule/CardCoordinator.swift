import AppKit
import LingvoCore
import OSLog

/// Runs the card schedule: one timer to the schedule's next deadline, timed
/// cards through the quiet rules, auto-close with the icon dot, pause and resume.
@MainActor
final class CardCoordinator {
    private let tutor: Tutor
    private let panel: CardPanelController
    private let contexts: CardContextBuilder
    private let pauseStore: PauseStore
    private let errors: ErrorPresenter
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "schedule")
    private var schedule: CardSchedule
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    /// Set after the status item exists; the coordinator only needs its anchor and dot.
    weak var statusItem: StatusItemController?

    init(
        tutor: Tutor,
        panel: CardPanelController,
        contexts: CardContextBuilder,
        settings: CardScheduleSettings,
        errors: ErrorPresenter
    ) {
        self.tutor = tutor
        self.panel = panel
        self.contexts = contexts
        self.pauseStore = contexts.pause
        self.errors = errors
        self.schedule = CardSchedule(settings: settings, startingAt: Date())
        panel.events = CardPanelEvents(
            engaged: { [weak self] in self?.engaged() },
            closed: { [weak self] card, action in self?.closed(card, with: action) }
        )
    }

    func start() {
        if let pausedUntil = pauseStore.pausedUntil() {
            schedule = schedule.paused(until: pausedUntil)
        }
        // Timers do not count time asleep; look at the clock again after wake.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        arm()
    }

    /// "Show word now" and ⌥⌘W: focus the shown card, reopen a waiting one, or ask for a new one.
    func showWordNow() {
        if panel.isShowing {
            panel.focus()
            engaged()
            return
        }
        if let waiting = schedule.waitingCard {
            show(waiting, engaged: true)
            return
        }
        do {
            switch try tutor.nextCard(context: contexts.context(for: .onDemand)) {
            case .card(let card):
                show(card, engaged: true)
            case .noCard(let reason):
                logger.notice("no card on demand: \(String(describing: reason), privacy: .public)")
                errors.inform(NoCardMessage.text(for: reason))
            }
        } catch {
            errors.show(error)
        }
    }

    /// A left click on the icon reopens the waiting card; returns `false` when there is none.
    func reopenWaitingCard() -> Bool {
        guard !panel.isShowing, let waiting = schedule.waitingCard else { return false }
        show(waiting, engaged: true)
        return true
    }

    func pause(_ option: PauseOption) {
        let until = option.pausedUntil(from: Date(), calendar: .current)
        pauseStore.pause(until: until)
        schedule = schedule.paused(until: until)
        logger.notice("paused until \(until, privacy: .public)")
        arm()
    }

    func resume() {
        pauseStore.resume()
        schedule = schedule.resumed(at: Date())
        logger.notice("resumed")
        arm()
    }

    var pausedUntil: Date? { pauseStore.pausedUntil() }

    private func arm() {
        timer?.invalidate()
        timer = nil
        statusItem?.showWaitingDot(schedule.waitingCard != nil)
        guard let deadline = schedule.nextDeadline else { return }
        let timer = Timer(fire: deadline, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        logger.notice("next deadline \(deadline, privacy: .public)")
    }

    private func tick() {
        let now = Date()
        switch schedule.due(at: now) {
        case .showCard:
            requestTimedCard(at: now)
        case .autoClose:
            panel.dismiss()
            schedule = schedule.autoClosed(at: now)
            logger.notice("card auto-closed, waiting behind the dot")
        case nil:
            break
        }
        arm()
    }

    private func requestTimedCard(at now: Date) {
        do {
            switch try tutor.nextCard(context: contexts.context(for: .timer)) {
            case .card(let card):
                show(card, engaged: false)
            case .noCard(let reason):
                logger.notice("no timed card: \(String(describing: reason), privacy: .public)")
                schedule = schedule.noCard(reason, at: now)
            }
        } catch {
            // A timer must not pop an alert over the learner's work; log and try again later.
            logger.error("timed card failed: \(String(describing: error), privacy: .public)")
            schedule = schedule.noCard(.noWordsAvailable, at: now)
        }
    }

    private func show(_ card: Card, engaged: Bool) {
        schedule = schedule.showing(card, at: Date(), engaged: engaged)
        panel.show(card, under: statusItem?.anchor, focused: engaged)
        logger.notice("card shown: \(card.headword, privacy: .public), focused: \(engaged)")
        arm()
    }

    private func engaged() {
        guard schedule.shownCard != nil else { return }
        schedule = schedule.engaged()
        arm()
    }

    private func closed(_ card: Card, with action: CardCloseAction) {
        switch action {
        case .next: break
        case .later: tutor.later(card)
        case .skip: tutor.skip(card)
        }
        schedule = schedule.closed(at: Date())
        logger.notice("card closed: \(card.headword, privacy: .public), \(String(describing: action), privacy: .public)")
        arm()
    }
}

enum NoCardMessage {
    static func text(for reason: NoCardReason) -> String {
        switch reason {
        case .noWordsAvailable:
            String(localized: "There are no words to practice right now.")
        case .paused, .quietHours, .focus, .fullScreen:
            // Only timed cards get these reasons, and the timer never shows a message.
            String(localized: "Cards are on hold right now.")
        }
    }
}
