import LingvoCore

/// The texts of the quick-add panel, built from the model.
extension QuickAddModel {
    /// "/rɪˈlʌktənt/ · adjective · outside Top‑1000".
    var metaLine: String {
        guard let preview else { return String(localized: "Type an English word") }
        guard let lookup = preview.lookup else {
            return String(localized: "Not in the dictionary: type your own translation")
        }
        let parts = [lookup.entry.ipa, lookup.entry.partOfSpeech.label, Self.tierLabel(lookup)]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    var footerText: String {
        switch message {
        case .standing(let standing): Self.label(for: standing)
        case .error(let text): text
        case nil: String(localized: "Will show in one of the next cards")
        }
    }

    var footerIsWarning: Bool { message != nil }

    private static func tierLabel(_ lookup: WordLookup) -> String {
        switch lookup.membership {
        case .inside(let tier):
            String(localized: "Top‑\(String(tier.maxRank)) · #\(String(lookup.entry.rank))")
        case .outside(let tier):
            String(localized: "outside Top‑\(String(tier.maxRank))")
        }
    }

    static func label(for standing: WordStanding) -> String {
        switch standing {
        case .notAdded: String(localized: "Will show in one of the next cards")
        case .mine: String(localized: "Already in My words")
        case .learning(let mastery): String(localized: "Already in Learning (\(mastery)/4)")
        case .learned: String(localized: "Already learned")
        }
    }
}
