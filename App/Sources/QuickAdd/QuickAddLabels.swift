import LingvoCore

extension QuickAddModel {
    /// "/rɪˈlʌktənt/ · adjective · outside Top‑1000". Empty when a machine
    /// translation fills the bubble: the "type your own" hint shows only when there is none.
    var metaLine: String {
        guard let candidate else { return String(localized: "Type an English or Russian word") }
        if needsEnglishWord {
            return machineBubble == nil ? String(localized: "Not in the dictionary: type the English word") : ""
        }
        guard let lookup = candidate.lookup else {
            // Wiktionary and system data have no rank or tier, so the line is only the transcription and the part of speech.
            let details = [candidate.ipa, candidate.partOfSpeech?.label].compactMap { $0 }
            if !details.isEmpty { return details.joined(separator: " · ") }
            // An English candidate for Russian input is a real translation: the line is empty without details.
            if isRussianInput { return "" }
            return machineBubble == nil ? String(localized: "Not in the dictionary: type your own translation") : ""
        }
        let parts = [lookup.entry.ipa, lookup.entry.partOfSpeech.label, Self.tierLabel(lookup)]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// Details from a dictionary do not make a translation: the line stays until a bubble comes.
    var missingTranslationNote: String? {
        guard !isRussianInput, let candidate, candidate.lookup == nil, candidate.translations.isEmpty,
              machineBubble == nil, !metaLine.isEmpty, metaLine != Self.notInDictionaryLine else { return nil }
        return Self.notInDictionaryLine
    }

    /// The short English definition under the bubbles; it is a hint and never saved.
    var definitionHint: String? { isRussianInput ? nil : candidate?.definitionHint }

    private static var notInDictionaryLine: String { String(localized: "Not in the dictionary: type your own translation") }

    var footerText: String {
        switch message {
        case .standing(let standing): Self.label(for: standing)
        case .error(let text): text
        case nil: String(localized: "I'll show it in one of the next cards")
        }
    }

    var footerIsWarning: Bool { message != nil }

    /// The panel follows the typed script; there is no direction toggle.
    var directionLabel: String { isRussianInput ? "RU → EN" : "EN → RU" }

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
        case .notAdded: String(localized: "I'll show it in one of the next cards")
        case .mine: String(localized: "Already in My words")
        case .learning(let mastery): String(localized: "Already in Learning (\(mastery)/\(WordRow.masteryGoal))")
        case .learned: String(localized: "Already learned")
        }
    }
}
