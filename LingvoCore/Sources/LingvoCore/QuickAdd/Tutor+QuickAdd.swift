import Foundation

extension Tutor {
    /// `nil` for blank text. Russian text lists English candidates; Russian
    /// text the dictionary does not know takes the English path.
    public func quickAddPreview(_ text: String) throws -> QuickAddPreview? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let isRussian = RussianText.isRussian(query)
        if isRussian, let preview = try russianPreview(query) {
            return preview
        }
        let lookup = try lookup(query)
        // Russian text the dictionaries do not know is an English word to type, not an English headword.
        let extended = lookup == nil && !isRussian ? try extendedDictionary?.entry(headword: query) : nil
        let headword = try lookup?.entry.headword
            ?? userDatabase.myWord(ignoringCase: query)?.headword
            ?? extended?.headword
            ?? query
        return QuickAddPreview(
            headword: headword,
            lookup: lookup,
            standing: try standing(of: headword),
            isRussianInput: isRussian,
            extended: extended
        )
    }

    /// Adds the word to My words. A queued dictionary word keeps its rank and
    /// takes the learner's translation and example; a word already in My words,
    /// learning or learned is left as it is (spec "Duplicate rules").
    public func addMyWord(_ word: NewMyWord) throws -> AddWordOutcome {
        let word = try word.validated()
        guard let preview = try quickAddPreview(word.text) else { throw LingvoCoreError.emptyWord }
        guard preview.canAdd else { return .alreadyAdded(preview.standing) }
        let extended = preview.candidates[0].extended
        try userDatabase.insert(MyWord(
            headword: preview.headword,
            translation: word.translation,
            // The extended example is a dictionary example: it goes on the card like the bundled one does.
            example: word.example ?? extended?.example,
            addedAt: clock.now(),
            ipa: extended?.ipa,
            partOfSpeech: extended?.partOfSpeech
        ))
        return .added(headword: preview.headword)
    }

    /// My words as card data, oldest first.
    func myWordEntries() throws -> [DictionaryEntry] {
        try userDatabase.myWords().map { word in
            word.cardEntry(from: try dictionary.entry(headword: word.headword))
        }
    }

    private func russianPreview(_ query: String) throws -> QuickAddPreview? {
        let entries = try dictionary.russianLookupEntries(query, limit: QuickAddPreview.maxCandidates)
        guard !entries.isEmpty else { return nil }
        let open = try openTier()
        let candidates = try entries.map { entry in
            QuickAddCandidate(
                headword: entry.headword,
                lookup: WordLookup(entry: entry, openTier: open),
                standing: try standing(of: entry.headword)
            )
        }
        return QuickAddPreview(russianText: query, candidates: candidates)
    }

    private func standing(of headword: String) throws -> WordStanding {
        if let progress = try userDatabase.progress(for: headword) {
            switch progress.status {
            case .learning: return .learning(mastery: progress.mastery)
            case .learned: return .learned
            }
        }
        return try userDatabase.myWord(headword: headword) == nil ? .notAdded : .mine
    }
}
