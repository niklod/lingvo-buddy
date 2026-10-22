import LingvoCore

/// The on-device translator quick add falls back to when the dictionary has no match.
/// Snapshots use a fake; the app uses the Apple Translation framework.
@MainActor
protocol MachineTranslator: AnyObject {
    func translate(_ request: MachineTranslationRequest) async -> MachineTranslation
    /// Shows the system download sheet for the pair; returns when the learner closes it.
    func downloadLanguagePack(for direction: MachineTranslationDirection) async
}
