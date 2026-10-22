import Foundation

/// Chooses the three wrong options of a card (spec "Distractors").
struct DistractorPicker {
    static let count = 3
    /// Distractors come at random from this many nearest-rank candidates, so the
    /// same word does not always show the same options.
    static let poolSize = 6

    let quizEntries: [DictionaryEntry]
    let random: any RandomSource

    /// Words of the same part of speech near the entry's rank. Never a word of
    /// the same synonym group or one that shares a translation, because that
    /// option would also be a right answer. If the part of speech has too few
    /// words, the nearest-rank words of other parts of speech fill the gap.
    func distractors(for entry: DictionaryEntry, direction: Direction) throws -> [String] {
        guard let correctText = Self.optionText(of: entry, direction: direction) else {
            throw LingvoCoreError.invalidDictionary("\(entry.headword) has no Russian translation")
        }
        let candidates = quizEntries
            .filter { isAllowed($0, against: entry) }
            .sorted { abs($0.rank - entry.rank) < abs($1.rank - entry.rank) }
        let samePOS = distinctTexts(candidates.filter { $0.partOfSpeech == entry.partOfSpeech },
                                    direction: direction, excluding: [correctText], limit: Self.poolSize)
        let chosen = Array(random.shuffled(samePOS).prefix(Self.count))
        let filler = distinctTexts(candidates.filter { $0.partOfSpeech != entry.partOfSpeech },
                                   direction: direction, excluding: Set(chosen + [correctText]),
                                   limit: Self.count - chosen.count)
        let result = chosen + filler
        guard result.count == Self.count else {
            throw LingvoCoreError.invalidDictionary("not enough distractors for \(entry.headword)")
        }
        return result
    }

    /// The text a learner sees on an option: the translation for EN→RU, the headword for RU→EN.
    static func optionText(of entry: DictionaryEntry, direction: Direction) -> String? {
        switch direction {
        case .ruToEn: entry.headword
        case .enToRu: entry.primaryRussian
        }
    }

    private func isAllowed(_ candidate: DictionaryEntry, against entry: DictionaryEntry) -> Bool {
        guard candidate.headword != entry.headword, candidate.primaryRussian != nil else { return false }
        // Lookup-tier words have no synonym group, so the group check below
        // cannot keep a synonym of a quiz word out of its wrong options.
        if entry.tier == .quiz, candidate.tier != .quiz || candidate.synonymGroup == nil { return false }
        if let group = entry.synonymGroup, candidate.synonymGroup == group { return false }
        let answers = Set(entry.translations[.russian] ?? [])
        return answers.isDisjoint(with: candidate.translations[.russian] ?? [])
    }

    private func distinctTexts(
        _ candidates: [DictionaryEntry],
        direction: Direction,
        excluding taken: Set<String>,
        limit: Int
    ) -> [String] {
        var seen = taken
        var texts: [String] = []
        for candidate in candidates where texts.count < limit {
            guard let text = Self.optionText(of: candidate, direction: direction),
                  seen.insert(text).inserted else { continue }
            texts.append(text)
        }
        return texts
    }
}
