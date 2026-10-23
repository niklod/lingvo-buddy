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

    /// A word only the extended dictionary (Wiktionary) has: several bubbles, IPA, part of speech and an example.
    static let codswallop = ExtendedEntry(
        headword: "codswallop",
        partOfSpeech: .noun,
        ipa: "/ˈkɒdzˌwɒləp/",
        translations: ["чепуха", "ерунда", "ахинея", "абсурд"],
        example: "That's a load of old codswallop.",
        russianExample: "Это сплошная чепуха."
    )

    static let skedaddle = ExtendedEntry(
        headword: "skedaddle",
        partOfSpeech: .verb,
        ipa: "/skɪˈdædəl/",
        translations: ["улепётывать", "удирать"],
        example: "The boys skedaddled when the farmer appeared.",
        russianExample: "Мальчишки удрали, когда появился фермер."
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
            extendedState("quick_add_extended", text: "codswallop"),
            extendedState("quick_add_extended_translation", text: "codswallop", showsExampleTranslation: true),
            extendedState("quick_add_extended_with_translator", text: "codswallop", answer: .translated("не используется")),
            russianState("quick_add_russian", text: "сомнение"),
            russianExtendedState("quick_add_russian_extended", text: "улепётывать"),
            machineState("quick_add_machine_en", text: "serendipity", answer: .translated("счастливая случайность")),
            machineState("quick_add_machine_en_variants", text: "skedaddle", answer: .translated("Сматываться, смотаться")),
            machineState("quick_add_machine_en_variants_second", text: "skedaddle", answer: .translated("Сматываться, смотаться"), chooses: .machine(1)),
            machineState("quick_add_machine_ru_variants", text: "болтун", answer: .translated("Chatterbox, blabbermouth")),
            machineState("quick_add_machine_en_custom", text: "serendipity", answer: .translated("счастливая случайность"), chooses: .custom),
            machineState("quick_add_machine_ru", text: "медленно", answer: .translated("slowly")),
            machineState(
                "quick_add_custom_bubbles", text: "skedaddle", answer: .translated("Сматываться, смотаться"),
                typesCustom: ["Смыться, удрать,", "слинять"]
            ),
            machineState(
                "quick_add_custom_bubbles_ru", text: "болтун", answer: .translated("Chatterbox, blabbermouth"),
                typesCustom: ["Windbag, ", "gasbag/"]
            ),
            machineState("quick_add_machine_missing_pack", text: "serendipity", answer: .languagePackMissing),
            machineState("quick_add_machine_error", text: "serendipity", answer: .failed),
        ]
    }

    /// A word the dictionary lacks, with the translator's answer already in. `typesCustom` goes into
    /// the custom field one text at a time, as the learner types or pastes it.
    private static func machineState(
        _ name: String, text: String, answer: MachineTranslation, chooses choice: TranslationChoice? = nil,
        typesCustom: [String] = []
    ) -> SnapshotState {
        panelState(name) {
            let model = QuickAddModel(text: text, translator: FakeMachineTranslator(answer: answer)) { query in
                QuickAddPreview(headword: query, lookup: nil, standing: .notAdded, isRussianInput: isCyrillic(query))
            }
            await model.machineTranslationSettled()
            if let choice { model.choose(choice) }
            if !typesCustom.isEmpty { model.choose(.custom) }
            for typed in typesCustom {
                if model.needsEnglishWord { model.englishWord = typed } else { model.customTranslation = typed }
            }
            return model
        }
    }

    /// The whole Cyrillic block, so "ё" and capitals count too.
    private static func isCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    /// The extended dictionary has the word. A translator that would answer shows no bubble: it is not asked.
    private static func extendedState(
        _ name: String, text: String, showsExampleTranslation: Bool = false, answer: MachineTranslation? = nil
    ) -> SnapshotState {
        panelState(name) {
            let model = QuickAddModel(
                text: text,
                translator: answer.map(FakeMachineTranslator.init(answer:)),
                showsExampleTranslation: showsExampleTranslation
            ) { query in
                QuickAddPreview(headword: query, lookup: nil, standing: .notAdded, extended: codswallop)
            }
            await model.machineTranslationSettled()
            return model
        }
    }

    private static func russianState(_ name: String, text: String) -> SnapshotState {
        panelState(name) {
            let model = QuickAddModel(text: text) { query in
                QuickAddPreview(russianText: query, candidates: doubtCandidates)
            }
            return model
        }
    }

    /// Russian text only the extended dictionary knows: English bubbles, the first with Wiktionary details.
    private static func russianExtendedState(_ name: String, text: String) -> SnapshotState {
        panelState(name) {
            let model = QuickAddModel(text: text) { query in
                let candidates = [
                    QuickAddCandidate(headword: "skedaddle", lookup: nil, standing: .notAdded, extended: skedaddle),
                    QuickAddCandidate(headword: "scram", lookup: nil, standing: .notAdded),
                    QuickAddCandidate(headword: "hightail", lookup: nil, standing: .notAdded),
                ]
                return QuickAddPreview(russianText: query, candidates: candidates)
            }
            return model
        }
    }

    /// Every quick-add state is a panel state, so `--check-panel-sizes` measures each of them.
    static func panelState(_ name: String, model: @escaping @MainActor () async -> QuickAddModel) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true, isPanel: true) {
            AnyView(QuickAddView(model: await model()).background(Theme.Palette.desktop))
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
        panelState(name) {
            let model = QuickAddModel(text: text, example: example, showsExampleTranslation: showsExampleTranslation) { query in
                let lookup = [reluctant, provide].first { $0.headword == query }.map { entry in
                    WordLookup(entry: entry, membership: entry.tier == .quiz ? .inside(.top1000) : .outside(.top1000))
                }
                return QuickAddPreview(headword: query, lookup: lookup, standing: standing)
            }
            return model
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
