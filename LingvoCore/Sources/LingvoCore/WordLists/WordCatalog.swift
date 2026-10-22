import Foundation

/// Sorts every word the learner can see into the Dictionary window lists.
/// Built from one read of the user state, so counts and rows always agree.
struct WordCatalog {
    /// A row with what search and ordering need.
    struct Item {
        let row: WordRow
        let lists: Set<WordList>
        /// Headword and every translation, folded for search.
        let searchText: [String]
        /// The latest answer, or when the word was added: Learning shows recent activity first.
        let activity: Date?
        let addedAt: Date?
        let rank: Int?
    }

    let items: [Item]

    init(
        cardEntries: [DictionaryEntry],
        tier: TopTier,
        progress: [String: WordProgress],
        myWords: [MyWord],
        overrides: [String: String],
        entry: (String) throws -> DictionaryEntry?
    ) rethrows {
        let mine = Dictionary(myWords.map { ($0.headword, $0) }, uniquingKeysWith: { first, _ in first })
        let cardIndex = Dictionary(cardEntries.map { ($0.headword, $0) }, uniquingKeysWith: { first, _ in first })
        var items: [Item] = []
        for word in myWords {
            let dictionaryEntry = try cardIndex[word.headword] ?? entry(word.headword)
            items.append(Self.item(
                headword: word.headword, entry: dictionaryEntry, myWord: word,
                progress: progress[word.headword], override: nil
            ))
        }
        for (headword, wordProgress) in progress where mine[headword] == nil {
            // A word dropped from a rebuilt dictionary has nothing to show.
            guard let dictionaryEntry = try cardIndex[headword] ?? entry(headword) else { continue }
            items.append(Self.item(
                headword: headword, entry: dictionaryEntry, myWord: nil,
                progress: wordProgress, override: overrides[headword]
            ))
        }
        for card in cardEntries where card.rank <= tier.maxRank && progress[card.headword] == nil && mine[card.headword] == nil {
            items.append(Self.item(
                headword: card.headword, entry: card, myWord: nil, progress: nil, override: overrides[card.headword]
            ))
        }
        self.items = items
    }

    func page(_ list: WordList, search: String, tier: TopTier) -> WordListPage {
        let query = Self.folded(search.trimmingCharacters(in: .whitespacesAndNewlines))
        let matching = query.isEmpty ? items : items.filter { item in
            item.searchText.contains { $0.contains(query) }
        }
        var counts = Dictionary(uniqueKeysWithValues: WordList.allCases.map { ($0, 0) })
        for item in matching {
            for itemList in item.lists { counts[itemList, default: 0] += 1 }
        }
        let rows = matching.filter { $0.lists.contains(list) }
            .sorted(by: Self.order(for: list))
            .map(\.row)
        return WordListPage(counts: counts, queueTier: tier, rows: rows)
    }

    private static func item(
        headword: String,
        entry: DictionaryEntry?,
        myWord: MyWord?,
        progress: WordProgress?,
        override: String?
    ) -> Item {
        let dictionaryTranslations = entry?.translations[.russian] ?? []
        let translation = myWord?.translation ?? override ?? dictionaryTranslations.first ?? ""
        let row = WordRow(
            headword: headword,
            translation: translation,
            mastery: progress?.mastery ?? 0,
            lastAnswer: progress.flatMap(lastAnswer(of:)),
            source: myWord == nil ? .rank(entry?.rank ?? 0) : .mine,
            status: progress?.status,
            // Only my words get the line: rows of bundled words look as the design has them.
            ipa: myWord.flatMap { entry?.ipa ?? $0.ipa },
            partOfSpeech: myWord.flatMap { entry?.partOfSpeech ?? $0.partOfSpeech }
        )
        return Item(
            row: row,
            lists: lists(progress: progress, isMine: myWord != nil),
            searchText: ([headword, translation] + dictionaryTranslations).map(folded),
            activity: progress?.lastAnsweredAt ?? myWord?.addedAt,
            addedAt: myWord?.addedAt,
            rank: entry?.rank
        )
    }

    private static func lists(progress: WordProgress?, isMine: Bool) -> Set<WordList> {
        var lists: Set<WordList> = isMine ? [.myWords] : []
        switch progress?.status {
        case .learned: lists.insert(.learned)
        case .learning: lists.insert(.learning)
        case nil: lists.insert(isMine ? .learning : .queue)
        }
        return lists
    }

    private static func lastAnswer(of progress: WordProgress) -> LastAnswer? {
        guard let outcome = progress.lastResult, let time = progress.lastAnsweredAt else { return nil }
        return LastAnswer(outcome: outcome, at: time)
    }

    /// "Хотя", "хотя" and "ХОТЯ" match, and so do "ё" and "е".
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func order(for list: WordList) -> (Item, Item) -> Bool {
        switch list {
        case .learning, .learned:
            { newestFirst($0.activity, $1.activity, $0, $1) }
        case .myWords:
            { newestFirst($0.addedAt, $1.addedAt, $0, $1) }
        case .queue:
            { ($0.rank ?? .max, $0.row.headword) < ($1.rank ?? .max, $1.row.headword) }
        }
    }

    private static func newestFirst(_ lhs: Date?, _ rhs: Date?, _ left: Item, _ right: Item) -> Bool {
        let leftTime = lhs ?? .distantPast
        let rightTime = rhs ?? .distantPast
        return leftTime == rightTime ? left.row.headword < right.row.headword : leftTime > rightTime
    }
}
