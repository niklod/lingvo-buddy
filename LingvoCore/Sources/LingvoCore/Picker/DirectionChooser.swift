import Foundation

/// Decides EN→RU or RU→EN for a card from the setting and the word's progress.
struct DirectionChooser {
    /// Mix shows about 70% EN→RU: recognition is easier than recall for new words.
    static let mixEnToRuPercent = 70

    let setting: DirectionSetting
    let random: any RandomSource

    func direction(for progress: WordProgress?) -> Direction {
        if let forced = forcedDirection(for: progress) {
            return forced
        }
        switch setting {
        case .enToRu: return .enToRu
        case .ruToEn: return .ruToEn
        case .mix: return random.nextInt(below: 100) < Self.mixEnToRuPercent ? .enToRu : .ruToEn
        }
    }

    /// One dot short of learned with a direction still missing: the next card
    /// must cover it, whatever the setting, or the word could never be learned.
    private func forcedDirection(for progress: WordProgress?) -> Direction? {
        guard let progress, progress.status == .learning,
              progress.mastery >= WordProgress.masteryGoal - 1 else { return nil }
        if !progress.enToRuCorrect { return .enToRu }
        if !progress.ruToEnCorrect { return .ruToEn }
        return nil
    }
}
