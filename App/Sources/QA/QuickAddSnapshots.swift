#if DEBUG
import LingvoCore
import SwiftUI

/// Quick add with the design's sample word (`design/screenshots/quick_add.png`)
/// and the duplicate, unknown-word and example-preview states.
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

    static var states: [SnapshotState] {
        [
            state("quick_add", text: "reluctant", example: "He was reluctant to admit the mistake.", standing: .notAdded),
            state("quick_add_learning", text: "reluctant", example: "", standing: .learning(mastery: 2)),
            state("quick_add_unknown", text: "kubernetes", example: "", standing: .notAdded),
            state("quick_add_example", text: "provide", example: "", standing: .notAdded),
        ]
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
