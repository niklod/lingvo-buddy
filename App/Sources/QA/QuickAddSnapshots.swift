#if DEBUG
import LingvoCore
import SwiftUI

/// Quick add with the design's sample word (`design/screenshots/quick_add.png`)
/// and the duplicate and unknown-word states.
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

    static var states: [SnapshotState] {
        [
            state("quick_add", text: "reluctant", example: "He was reluctant to admit the mistake.", standing: .notAdded),
            state("quick_add_learning", text: "reluctant", example: "", standing: .learning(mastery: 2)),
            state("quick_add_unknown", text: "kubernetes", example: "", standing: .notAdded),
        ]
    }

    private static func state(_ name: String, text: String, example: String, standing: WordStanding) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            let model = QuickAddModel(text: text, example: example) { query in
                let lookup = query == reluctant.headword
                    ? WordLookup(entry: reluctant, membership: .outside(.top1000))
                    : nil
                return QuickAddPreview(headword: query, lookup: lookup, standing: standing)
            }
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }
}
#endif
