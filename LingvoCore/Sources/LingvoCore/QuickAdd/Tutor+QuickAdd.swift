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
        // Russian text the dictionaries do not know is an English word to type, not an English headword.
        let candidate = try englishCandidate(query, detailed: !isRussian)
        return QuickAddPreview(candidate: candidate, isRussianInput: isRussian)
    }

    /// What the panel shows for an English word the card gets for Russian input: a bubble the learner
    /// picks, a custom word, or a machine translation. `nil` for blank text. Russian text has no
    /// English entry, so it gets none of the extended and system details.
    public func englishDetails(_ text: String) throws -> QuickAddCandidate? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        return try englishCandidate(query, detailed: !RussianText.isRussian(query))
    }

    /// Adds the word to My words. A queued dictionary word keeps its rank and
    /// takes the learner's translation and example; a word already in My words,
    /// learning or learned is left as it is (spec "Duplicate rules").
    public func addMyWord(_ word: NewMyWord) throws -> AddWordOutcome {
        let word = try word.validated()
        // Russian text would preview as Russian input and add its first English candidate instead.
        guard !RussianText.isRussian(word.text) else { throw LingvoCoreError.notEnglishWord(word.text) }
        guard let preview = try quickAddPreview(word.text) else { throw LingvoCoreError.emptyWord }
        guard preview.canAdd else { return .alreadyAdded(preview.standing) }
        let candidate = preview.candidates[0]
        try userDatabase.insert(MyWord(
            headword: preview.headword,
            translation: word.translation,
            // The extended or system example is a dictionary example: it goes on the card like the bundled one does.
            example: word.example ?? candidate.fallbackExample,
            addedAt: clock.now(),
            // A CSV import refuses a longer IPA, so saving one would make the backup fail to import.
            ipa: candidate.fallbackIPA.flatMap { $0.count <= NewMyWord.maxIPALength ? $0 : nil },
            partOfSpeech: candidate.fallbackPartOfSpeech,
            russianExample: word.example == nil ? candidate.fallbackRussianExample : nil
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
        guard !entries.isEmpty else { return try extendedRussianPreview(query) }
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

    private func englishCandidate(_ query: String, detailed: Bool) throws -> QuickAddCandidate {
        let lookup = try lookup(query)
        let extended = lookup == nil && detailed ? try extendedDictionary?.entry(headword: query) : nil
        let headword = try lookup?.entry.headword
            ?? userDatabase.myWord(ignoringCase: query)?.headword
            ?? extended?.headword
            ?? query
        return QuickAddCandidate(
            headword: headword,
            lookup: lookup,
            standing: try standing(of: headword),
            extended: extended,
            system: lookup == nil && detailed ? systemEntry(for: headword) : nil
        )
    }

    private func systemEntry(for headword: String) -> SystemEntry? {
        systemDictionary?.definition(of: headword).flatMap { SystemEntry.parse($0, for: headword) }
    }

    /// Bundled Russian candidates always win, so this runs only for Russian text the bundled dictionary lacks.
    private func extendedRussianPreview(_ query: String) throws -> QuickAddPreview? {
        let headwords = try extendedDictionary?.englishTranslations(
            forRussian: query, limit: QuickAddPreview.maxCandidates
        ) ?? []
        guard !headwords.isEmpty else { return nil }
        let open = try openTier()
        let candidates = try headwords.map { headword in
            let lookup = try dictionary.lookupEntry(headword).map { WordLookup(entry: $0, openTier: open) }
            return QuickAddCandidate(
                headword: lookup?.entry.headword ?? headword,
                lookup: lookup,
                standing: try standing(of: lookup?.entry.headword ?? headword),
                extended: lookup == nil ? try extendedDictionary?.entry(headword: headword) : nil
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
