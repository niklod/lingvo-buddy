import Observation
import OSLog
import SwiftUI
import Translation

/// The Apple Translation framework behind `MachineTranslator`.
///
/// On macOS 15 a `TranslationSession` exists only inside the `translationTask`
/// modifier of a visible view, so each call parks a job here, changes the
/// configuration, and `SystemTranslatorHost` runs the job with the session it gets.
@MainActor
@Observable
final class SystemTranslator: MachineTranslator {
    fileprivate enum Job: Sendable {
        case translate(String, CheckedContinuation<MachineTranslation, Never>)
        case prepare(CheckedContinuation<Void, Never>)
    }

    private(set) var configuration: TranslationSession.Configuration?
    @ObservationIgnored private var job: Job?
    @ObservationIgnored private let logger = SystemTranslator.logger
    fileprivate nonisolated static let logger = Logger.app(category: "machine-translation")

    func translate(_ request: MachineTranslationRequest) async -> MachineTranslation {
        let pair = request.direction.languagePair
        // `translate` itself asks to download a missing pack; only the learner's click may do that.
        switch await LanguageAvailability().status(from: pair.source, to: pair.target) {
        case .installed:
            break
        case .supported:
            return .languagePackMissing
        case .unsupported:
            logger.error("the system does not support \(String(describing: request.direction), privacy: .public)")
            return .failed
        @unknown default:
            return .failed
        }
        guard !Task.isCancelled else { return .failed }
        return await withCheckedContinuation { continuation in
            start(.translate(request.text, continuation), pair: pair)
        }
    }

    func downloadLanguagePack(for direction: MachineTranslationDirection) async {
        await withCheckedContinuation { continuation in
            start(.prepare(continuation), pair: direction.languagePair)
        }
    }

    /// The panel closes: its view and the session go away, so no job may wait for them.
    func cancelAll() {
        finishWaitingJob()
        configuration = nil
    }

    /// The session is not Sendable, so it stays in the `translationTask` closure;
    /// only the job comes from the main actor.
    fileprivate func takeJob() -> Job? {
        defer { job = nil }
        return job
    }

    private func start(_ newJob: Job, pair: LanguagePair) {
        // A newer keystroke replaced the older request; its caller drops the result anyway.
        finishWaitingJob()
        job = newJob
        if configuration?.source == pair.source, configuration?.target == pair.target {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(source: pair.source, target: pair.target)
        }
    }

    private func finishWaitingJob() {
        switch job {
        case .translate(_, let continuation): continuation.resume(returning: .failed)
        case .prepare(let continuation): continuation.resume()
        case nil: break
        }
        job = nil
    }
}

/// Gives `SystemTranslator` its sessions: attach it to the quick-add view.
struct SystemTranslatorHost: ViewModifier {
    let translator: SystemTranslator

    func body(content: Content) -> some View {
        content.translationTask(translator.configuration) { @Sendable session in
            await Self.run(translator, with: session)
        }
    }

    /// Called each time the configuration changes.
    private nonisolated static func run(_ translator: SystemTranslator, with session: TranslationSession) async {
        guard let job = await translator.takeJob() else { return }
        switch job {
        case .translate(let text, let continuation):
            continuation.resume(returning: await translate(text, with: session))
        case .prepare(let continuation):
            do {
                try await session.prepareTranslation()
            } catch {
                SystemTranslator.logger.error("language pack download failed: \(String(describing: error), privacy: .public)")
            }
            continuation.resume()
        }
    }

    private nonisolated static func translate(_ text: String, with session: TranslationSession) async -> MachineTranslation {
        do {
            let response = try await session.translate(text)
            return .translated(response.targetText)
        } catch {
            SystemTranslator.logger.error("translation failed: \(String(describing: error), privacy: .public)")
            return .failed
        }
    }
}

private struct LanguagePair {
    let source: Locale.Language
    let target: Locale.Language
}

private extension MachineTranslationDirection {
    var languagePair: LanguagePair {
        let english = Locale.Language(identifier: "en")
        let russian = Locale.Language(identifier: "ru")
        return switch self {
        case .englishToRussian: LanguagePair(source: english, target: russian)
        case .russianToEnglish: LanguagePair(source: russian, target: english)
        }
    }
}
