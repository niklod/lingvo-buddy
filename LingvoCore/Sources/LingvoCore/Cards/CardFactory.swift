import Foundation

/// Turns a dictionary entry and its progress into a ready card.
struct CardFactory {
    static let distractorCount = 3

    let quizEntries: [DictionaryEntry]
    let random: any RandomSource

    func card(for entry: DictionaryEntry, progress: WordProgress?) throws -> Card {
        guard let answer = entry.primaryRussian else {
            throw LingvoCoreError.invalidDictionary("\(entry.headword) has no Russian translation")
        }
        let distractors = distractors(for: entry, answer: answer)
        guard distractors.count == Self.distractorCount else {
            throw LingvoCoreError.invalidDictionary("not enough distractors for \(entry.headword)")
        }
        let options = random.shuffled([answer] + distractors)
        return Card(
            headword: entry.headword,
            prompt: entry.headword,
            direction: .enToRu,
            kind: .new,
            source: .rank(entry.rank),
            ipa: entry.ipa,
            partOfSpeech: entry.partOfSpeech,
            options: options,
            correctIndex: options.firstIndex(of: answer) ?? 0,
            example: entry.example,
            mastery: progress?.mastery ?? 0
        )
    }

    /// Nearest-rank words with a translation that differs from every other option.
    private func distractors(for entry: DictionaryEntry, answer: String) -> [String] {
        let candidates = quizEntries
            .filter { $0.headword != entry.headword }
            .sorted { abs($0.rank - entry.rank) < abs($1.rank - entry.rank) }
        var chosen: [String] = []
        for candidate in candidates {
            guard let text = candidate.primaryRussian, text != answer, !chosen.contains(text) else { continue }
            chosen.append(text)
            if chosen.count == Self.distractorCount { break }
        }
        return chosen
    }
}
