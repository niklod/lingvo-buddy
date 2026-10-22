/// The two ways quick add asks the system translator.
enum MachineTranslationDirection: Equatable, Sendable {
    /// An English word outside the dictionary: the suggestion is the card's translation.
    case englishToRussian
    /// Russian text with no English candidates: the suggestion is the card's English word.
    case russianToEnglish
}

struct MachineTranslationRequest: Equatable, Sendable {
    let text: String
    let direction: MachineTranslationDirection
}

enum MachineTranslation: Equatable, Sendable {
    case translated(String)
    /// The system has the language pair but not its offline pack. Only the
    /// learner's click may start the download, so the translator never does it on its own.
    case languagePackMissing
    /// The details go to the log; the panel shows one short line.
    case failed
}

/// The on-device translator quick add falls back to when the dictionary has no match.
/// Snapshots use a fake; the app uses the Apple Translation framework.
@MainActor
protocol MachineTranslator: AnyObject {
    func translate(_ request: MachineTranslationRequest) async -> MachineTranslation
    /// Shows the system download sheet for the pair; returns when the learner closes it.
    func downloadLanguagePack(for direction: MachineTranslationDirection) async
}
