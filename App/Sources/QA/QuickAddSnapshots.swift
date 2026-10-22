#if DEBUG
import LingvoCore
import SwiftUI

/// Quick add with the design's sample word (`design/screenshots/quick_add.png`)
/// and the duplicate, unknown-word, example-preview and Russian-input states.
@MainActor
enum QuickAddSnapshots {
    static let reluctant = DictionaryEntry(
        headword: "reluctant",
        rank: 4870,
        partOfSpeech: .adjective,
        ipa: "/rɪˈlʌktənt/",
        example: nil,
        synonymGroup: nil,
        tier: .lookup,
        translations: [.russian: ["неохотный", "нежелающий", "сопротивляющийся"]]
    )

    static let provide = DictionaryEntry(
        headword: "provide",
        rank: 254,
        partOfSpeech: .verb,
        ipa: "/prəˈvaɪd/",
        example: "The hotel provides free breakfast.",
        synonymGroup: "provide",
        tier: .quiz,
        translations: [.russian: ["обеспечивать", "предоставлять"]],
        russianExample: "Отель предоставляет бесплатный завтрак."
    )

    /// English words for «сомнение»; the second one is already in My words.
    static let doubtCandidates = [
        candidate("doubt", rank: 2210, ipa: "/daʊt/", ru: ["сомнение", "сомневаться"], standing: .notAdded),
        candidate("uncertainty", rank: 3900, ipa: "/ʌnˈsɜːtənti/", ru: ["неуверенность", "сомнение"], standing: .mine),
        candidate("hesitation", rank: 6100, ipa: "/ˌhezɪˈteɪʃən/", ru: ["колебание", "сомнение"], standing: .notAdded),
    ]

    static var states: [SnapshotState] {
        [
            state("quick_add", text: "reluctant", example: "He was reluctant to admit the mistake.", standing: .notAdded),
            state("quick_add_learning", text: "reluctant", example: "", standing: .learning(mastery: 2)),
            state("quick_add_unknown", text: "kubernetes", example: "", standing: .notAdded),
            state("quick_add_example", text: "provide", example: "", standing: .notAdded),
            russianState("quick_add_russian", text: "сомнение"),
        ]
    }

    private static func russianState(_ name: String, text: String) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            let model = QuickAddModel(text: text) { query in
                QuickAddPreview(russianText: query, candidates: doubtCandidates)
            }
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }

    private static func candidate(
        _ headword: String, rank: Int, ipa: String, ru: [String], standing: WordStanding
    ) -> QuickAddCandidate {
        let entry = DictionaryEntry(
            headword: headword,
            rank: rank,
            partOfSpeech: .noun,
            ipa: ipa,
            example: nil,
            synonymGroup: nil,
            tier: .lookup,
            translations: [.russian: ru]
        )
        let lookup = WordLookup(entry: entry, membership: .outside(.top1000))
        return QuickAddCandidate(headword: headword, lookup: lookup, standing: standing)
    }

    private static func state(_ name: String, text: String, example: String, standing: WordStanding) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            let model = QuickAddModel(text: text, example: example) { query in
                let lookup = [reluctant, provide].first { $0.headword == query }.map { entry in
                    WordLookup(entry: entry, membership: entry.tier == .quiz ? .inside(.top1000) : .outside(.top1000))
                }
                return QuickAddPreview(headword: query, lookup: lookup, standing: standing)
            }
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }
}
#endif
