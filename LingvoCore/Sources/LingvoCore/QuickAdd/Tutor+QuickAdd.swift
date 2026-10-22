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
        let headword = try lookup?.entry.headword ?? userDatabase.myWord(ignoringCase: query)?.headword ?? query
        return QuickAddPreview(
            headword: headword,
            lookup: lookup,
            standing: try standing(of: headword),
            isRussianInput: isRussian
        )
    }

    /// Adds the word to My words. A queued dictionary word keeps its rank and
    /// takes the learner's translation and example; a word already in My words,
    /// learning or learned is left as it is (spec "Duplicate rules").
    public func addMyWord(_ word: NewMyWord) throws -> AddWordOutcome {
        let word = try word.validated()
        guard let preview = try quickAddPreview(word.text) else { throw LingvoCoreError.emptyWord }
        guard preview.canAdd else { return .alreadyAdded(preview.standing) }
        try userDatabase.insert(MyWord(
            headword: preview.headword,
            translation: word.translation,
            example: word.example,
            addedAt: clock.now()
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
