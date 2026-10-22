import AppKit
import LingvoCore
import OSLog

/// Runs the card schedule: one timer to the schedule's next deadline, timed
/// cards through the quiet rules, auto-close with the icon dot, pause and resume.
@MainActor
final class CardCoordinator {
    /// Apple's energy guide asks for at least 10 % so the system can batch wakeups.
    private static let timerToleranceShare = 0.1
    private static let maxTimerTolerance: TimeInterval = 60

    private let tutor: Tutor
    private let panel: CardPanelController
    private let contexts: CardContextBuilder
    private let pauseStore: PauseStore
    private let settings: SettingsModel
    private let errors: ErrorPresenter
    private let clock: any TutorClock
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "schedule")
    private var schedule: CardSchedule
    /// The quiet rule that held the last timed card back.
    private var hold: ScheduleHold?
    private var timer: Timer?
    /// The coordinator lives as long as the app, so the tokens are never removed.
    private var observers: [NSObjectProtocol] = []

    /// Set after the status item exists; the coordinator only needs its anchor and dot.
    weak var statusItem: StatusItemController?
    /// The tray and a timed card both hang under the icon, so a card waits while the tray is open.
    var isTrayOpen: () -> Bool = { false }

    init(
        tutor: Tutor,
        panel: CardPanelController,
        contexts: CardContextBuilder,
        scheduleSettings: CardScheduleSettings,
        errors: ErrorPresenter,
        clock: any TutorClock = SystemClock()
    ) {
        self.tutor = tutor
        self.panel = panel
        self.contexts = contexts
        self.pauseStore = contexts.pause
        self.settings = contexts.settings
        self.errors = errors
        self.clock = clock
        self.schedule = CardSchedule(settings: scheduleSettings, startingAt: clock.now())
        panel.events = CardPanelEvents(
            engaged: { [weak self] in self?.engaged() },
            closed: { [weak self] card, action in self?.closed(card, with: action) }
        )
    }

    func start() {
        settings.onChange { [weak self] old, new in
            // Other settings act through the tutor and the context; only the interval moves the timer.
            if old.cardInterval != new.cardInterval {
                self?.applyInterval(new.cardInterval)
            }
        }
        reapplyStoredPause()
        // Timers do not count time asleep; look at the clock again after wake.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDataChanges.notification, object: nil, queue: .main
        ) { [weak self] note in
            let stale = UserDataChanges.staleCards(in: note)
            MainActor.assumeIsolated { self?.dropCards(stale) }
        })
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
            switch try tutor.nextCard(context: contexts.context(for: .onDemand, at: clock.now())) {
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

    /// The tray is about to open where the card hangs. An unanswered card waits
    /// behind the dot (a click on the icon brings it back); an answered one is done.
    func setAsideShownCard() {
        guard panel.isShowing, let card = schedule.shownCard else { return }
        let isAnswered = panel.isAnswered
        panel.dismiss()
        let now = clock.now()
        schedule = isAnswered ? schedule.closed(at: now) : schedule.autoClosed(at: now)
        logger.notice("card set aside for the tray: \(card.headword, privacy: .private)")
        arm()
    }

    func pause(_ option: PauseOption) {
        let until = option.pausedUntil(from: clock.now(), calendar: .current)
        pauseStore.pause(until: until)
        schedule = schedule.paused(until: until)
        logger.notice("paused until \(until, privacy: .public)")
        arm()
    }

    func resume() {
        pauseStore.resume()
        schedule = schedule.resumed(at: clock.now())
        logger.notice("resumed")
        arm()
    }

    /// What the tray menu shows: "Next in X min · every N min", the pause end or the hold.
    var trayInfo: TrayScheduleInfo {
        TrayScheduleInfo(
            nextCardAt: schedule.nextCardAt,
            interval: schedule.settings.interval,
            pausedUntil: pauseStore.pausedUntil(now: clock.now()),
            hold: hold
        )
    }

    /// Tray interval submenu: saved like a Settings change, then applied by `applyInterval`.
    func changeInterval(_ seconds: TimeInterval) {
        settings.update { $0.replacing(cardInterval: seconds) }
    }

    /// The countdown restarts with the new interval; a pause still holds cards back.
    private func applyInterval(_ interval: TimeInterval) {
        do {
            schedule = schedule.withSettings(try CardScheduleSettings(interval: interval), at: clock.now())
        } catch {
            errors.show(error)
            return
        }
        reapplyStoredPause()
        logger.notice("interval changed to \(interval, privacy: .public) s")
        arm()
    }

    private func reapplyStoredPause() {
        guard let until = pauseStore.pausedUntil(now: clock.now()) else { return }
        schedule = schedule.paused(until: until)
    }

    /// A deleted, reset or re-learned word must not come back as a card: it
    /// would fail on answer, or change progress the learner just set by hand.
    private func dropCards(_ stale: UserDataChanges.StaleCards) {
        guard stale != .none else { return }
        let now = clock.now()
        if let shown = schedule.shownCard, stale.contains(shown.headword) {
            panel.dismiss()
            schedule = schedule.closed(at: now)
            logger.notice("shown card dropped: \(shown.headword, privacy: .private)")
        }
        if let waiting = schedule.waitingCard, stale.contains(waiting.headword) {
            schedule = schedule.droppingWaitingCard(at: now)
            logger.notice("waiting card dropped: \(waiting.headword, privacy: .private)")
        }
        arm()
    }

    private func arm() {
        timer?.invalidate()
        timer = nil
        statusItem?.showWaitingDot(schedule.waitingCard != nil)
        guard let deadline = schedule.nextDeadline else { return }
        let timer = Timer(fire: deadline, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        let wait = max(deadline.timeIntervalSince(clock.now()), 0)
        timer.tolerance = min(wait * Self.timerToleranceShare, Self.maxTimerTolerance)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        logger.notice("next deadline \(deadline, privacy: .public)")
    }

    private func tick() {
        let now = clock.now()
        switch schedule.due(at: now) {
        case .showCard where isTrayOpen():
            schedule = schedule.retryingSoon(at: now)
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
            switch try tutor.nextCard(context: contexts.context(for: .timer, at: now)) {
            case .card(let card):
                show(card, engaged: false)
            case .noCard(let reason):
                logger.notice("no timed card: \(String(describing: reason), privacy: .public)")
                hold = ScheduleHold(reason: reason, quietHoursEnd: contexts.quietHoursEnd(after: now))
                schedule = schedule.noCard(reason, at: now)
            }
        } catch {
            // A timer must not pop an alert over the learner's work; log and try again later.
            logger.error("timed card failed: \(String(describing: error), privacy: .private)")
            schedule = schedule.noCard(.noWordsAvailable, at: now)
        }
    }

    private func show(_ card: Card, engaged: Bool) {
        hold = nil
        schedule = schedule.showing(card, at: clock.now(), engaged: engaged)
        panel.show(card, under: statusItem?.anchor, focused: engaged)
        logger.notice("card shown: \(card.headword, privacy: .private), focused: \(engaged)")
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
        schedule = schedule.closed(at: clock.now())
        logger.notice("card closed: \(card.headword, privacy: .private), \(String(describing: action), privacy: .public)")
        arm()
    }
}
