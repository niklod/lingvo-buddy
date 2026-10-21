import Foundation

extension Tutor {
    /// The Dictionary window: counts of every list and the rows of `list`.
    /// `search` matches the word or any of its translations, ignoring case;
    /// the counts then count matches only.
    public func wordList(_ list: WordList, search: String = "") throws -> WordListPage {
        let progress = try userDatabase.allProgress()
        let tier = try openTier(progress: progress)
        let catalog = try WordCatalog(
            cardEntries: dictionary.quizEntries,
            tier: tier,
            progress: progress,
            myWords: userDatabase.myWords(),
            overrides: userDatabase.translationOverrides(),
            entry: { try dictionary.entry(headword: $0) }
        )
        return catalog.page(list, search: search, tier: tier)
    }
}
