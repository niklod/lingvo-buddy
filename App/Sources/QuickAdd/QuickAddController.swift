import AppKit
import LingvoCore
import OSLog

/// Opens the quick-add panel (⌥⌘L, Services, the tray field) and adds the word
/// through the tutor. Every entry point goes through `open(prefill:)`.
@MainActor
final class QuickAddController {
    /// Spotlight sits about a fifth of the screen below the top edge.
    private static let topOffsetShare: CGFloat = 0.2

    private let tutor: Tutor
    private let logger = Logger.app(category: "quick-add")
    private var panel: QuickAddPanel?
    private var model: QuickAddModel?
    private var translator: SystemTranslator?
    private var outsideClickMonitor: Any?

    init(tutor: Tutor) {
        self.tutor = tutor
    }

    var isShowing: Bool { panel?.isVisible == true }

    func open(prefill: String? = nil, example: String = "") {
        close()
        let tutor = tutor
        let translator = SystemTranslator()
        let model = QuickAddModel(
            text: Self.cleaned(prefill),
            example: String(example.prefix(NewMyWord.maxExampleLength)),
            translator: translator,
            showsExampleTranslation: tutor.settings.showsExampleTranslation,
            details: { try tutor.englishDetails($0) },
            lookup: { try tutor.quickAddPreview($0) }
        )
        let panel = QuickAddPanel()
        panel.setContent(QuickAddView(
            model: model,
            actions: QuickAddActions(
                submit: { [weak self] in self?.submit() },
                cancel: { [weak self] in self?.close() }
            )
        ).modifier(SystemTranslatorHost(translator: translator)))
        panel.onKey = { [weak self] command in self?.handle(command) ?? false }
        panel.onResignKey = { [weak self] in self?.closeUnlessDownloading() }
        panel.setFrameOrigin(Self.origin(for: panel.frame.size))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.model = model
        self.translator = translator
        watchOutsideClicks()
        logger.notice("quick add opened, prefilled: \(prefill != nil, privacy: .public)")
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        model = nil
        translator?.cancelAll()
        translator = nil
        panel.onResignKey = {}
        panel.orderOut(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    /// The system download sheet takes the keys and the clicks; the panel must
    /// stay, or its translation session goes away while the pack downloads.
    private func closeUnlessDownloading() {
        guard model?.isDownloadingLanguagePack != true else { return }
        close()
    }

    private func handle(_ command: QuickAddKeyCommand) -> Bool {
        switch command {
        case .submit: submit()
        case .cancel: close()
        case .previousCandidate: return model?.moveCandidate(by: -1) ?? false
        case .nextCandidate: return model?.moveCandidate(by: 1) ?? false
        }
        return true
    }

    private func submit() {
        guard let model, let word = model.submission() else { return }
        do {
            switch try tutor.addMyWord(word) {
            case .added(let headword):
                logger.notice("added my word \(headword, privacy: .private)")
                close()
                UserDataChanges.post()
            case .alreadyAdded(let standing):
                model.show(.standing(standing))
            }
        } catch {
            logger.error("quick add failed: \(String(describing: error), privacy: .private)")
            model.show(.error(Self.message(for: error)))
        }
    }

    /// Core errors are written for the learner; any other error (a database error) holds SQL text,
    /// which goes to the log only.
    private static func message(for error: Error) -> String {
        if let error = error as? LingvoCoreError { return error.localizedDescription }
        return String(localized: "The word could not be added. Try again.")
    }

    /// A Services selection can span lines or carry punctuation around the word.
    private static func cleaned(_ text: String?) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return String(trimmed.prefix(NewMyWord.maxWordLength))
    }

    /// Centered on the screen with the pointer, like Spotlight: the hotkey can
    /// come while the menu bar is hidden, so the status item is no anchor here.
    private static func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return .zero }
        let top = frame.maxY - frame.height * topOffsetShare
        return NSPoint(x: frame.midX - size.width / 2, y: top - size.height)
    }

    /// Clicks in other apps reach only a global monitor; resigning key covers
    /// the rest (⌘⇥, a click on another window of this app).
    private func watchOutsideClicks() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeUnlessDownloading() }
        }
    }
}
