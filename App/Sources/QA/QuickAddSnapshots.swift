#if DEBUG
import LingvoCore
import SwiftUI

/// Quick add with the design's sample word (`design/screenshots/quick_add.png`)
/// and the duplicate, unknown-word, example-preview, Russian-input and machine translation states.
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
            state("quick_add_example_translation", text: "provide", example: "", standing: .notAdded, showsExampleTranslation: true),
            russianState("quick_add_russian", text: "сомнение"),
            machineState("quick_add_machine_en", text: "serendipity", answer: .translated("счастливая случайность")),
            machineState("quick_add_machine_en_custom", text: "serendipity", answer: .translated("счастливая случайность"), choosesCustom: true),
            machineState("quick_add_machine_ru", text: "медленно", answer: .translated("slowly")),
            machineState("quick_add_machine_missing_pack", text: "serendipity", answer: .languagePackMissing),
            machineState("quick_add_machine_error", text: "serendipity", answer: .failed),
        ]
    }

    /// A word the dictionary lacks, with the translator's answer already in.
    private static func machineState(
        _ name: String, text: String, answer: MachineTranslation, choosesCustom: Bool = false
    ) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            let model = QuickAddModel(text: text, translator: FakeMachineTranslator(answer: answer)) { query in
                QuickAddPreview(headword: query, lookup: nil, standing: .notAdded, isRussianInput: query == "медленно")
            }
            await model.machineTranslationSettled()
            if choosesCustom { model.choose(.custom) }
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
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

    private static func state(
        _ name: String,
        text: String,
        example: String,
        standing: WordStanding,
        showsExampleTranslation: Bool = false
    ) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            let model = QuickAddModel(text: text, example: example, showsExampleTranslation: showsExampleTranslation) { query in
                let lookup = [reluctant, provide].first { $0.headword == query }.map { entry in
                    WordLookup(entry: entry, membership: entry.tier == .quiz ? .inside(.top1000) : .outside(.top1000))
                }
                return QuickAddPreview(headword: query, lookup: lookup, standing: standing)
            }
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }
}

/// Answers every request the same way, at once.
@MainActor
final class FakeMachineTranslator: MachineTranslator {
    private let answer: MachineTranslation

    init(answer: MachineTranslation) {
        self.answer = answer
    }

    func translate(_ request: MachineTranslationRequest) async -> MachineTranslation {
        answer
    }

    func downloadLanguagePack(for direction: MachineTranslationDirection) async {}
}
#endif
