#if DEBUG
import LingvoCore
import SwiftUI

/// Quick add for Russian text the bundled dictionary lacks: the details follow the English word of the card.
@MainActor
enum ChainedLookupSnapshots {
    // swiftlint:disable:next line_length
    private static let skedaddleText = "skedaddle ske·dad·dle | skəˈdad(ə)l | verb [no object] informal depart quickly or hurriedly; run away: when he saw us, he skedaddled. ORIGIN mid 19th century: of unknown origin."

    // swiftlint:disable:next line_length
    private static let codswallopText = "codswallop cods·wal·lop | ˈkädzˌwäləp | noun British English informal nonsense: I think that's a right load of old codswallop. ORIGIN 1920s: probably an alteration of cod walloper."

    private static let scram = ExtendedEntry(
        headword: "scram",
        partOfSpeech: .verb,
        ipa: "/skræm/",
        translations: ["убираться"],
        example: "Scram, before the guard sees you!",
        russianExample: "Уходи, пока тебя не увидел охранник!"
    )

    static var states: [SnapshotState] {
        [
            pickedBubble("quick_add_russian_chained_pick"),
            machineWord("quick_add_russian_chained_machine"),
            typedWord("quick_add_russian_chained_typed"),
        ]
    }

    /// What the Tutor answers for an English word: extended data first, then the system dictionary.
    private static func details(_ word: String) -> QuickAddCandidate {
        let extended = [QuickAddSnapshots.codswallop, QuickAddSnapshots.skedaddle, scram].first { $0.headword == word }
        let text = ["skedaddle": skedaddleText, "codswallop": codswallopText][word]
        let system = text.flatMap { SystemEntry.parse($0, for: word) }
        return QuickAddCandidate(headword: word, lookup: nil, standing: .notAdded, extended: extended, system: system)
    }

    /// The learner picks the second English bubble: its details replace those of the first.
    private static func pickedBubble(_ name: String) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true, isPanel: true) {
            let model = QuickAddModel(
                text: "удирать",
                details: { details($0) },
                lookup: { query in
                    let candidates = ["skedaddle", "scram", "hightail"].map { details($0) }
                    return QuickAddPreview(russianText: query, candidates: candidates)
                }
            )
            model.chooseCandidate(1)
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }

    /// Unknown Russian text: the machine translation is the English word, and its details come after it.
    private static func machineWord(_ name: String) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true, isPanel: true) {
            let model = await unknownRussianModel()
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }

    /// The learner types their own English word over the machine one.
    private static func typedWord(_ name: String) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true, isPanel: true) {
            let model = await unknownRussianModel()
            model.choose(.custom)
            model.englishWord = "skedaddle"
            await model.machineTranslationSettled()
            return AnyView(QuickAddView(model: model).background(Theme.Palette.desktop))
        }
    }

    private static func unknownRussianModel() async -> QuickAddModel {
        let model = QuickAddModel(
            text: "чепуха",
            translator: FakeMachineTranslator(answer: .translated("codswallop")),
            details: { details($0) },
            lookup: { query in QuickAddPreview(headword: query, lookup: nil, standing: .notAdded, isRussianInput: true) }
        )
        await model.machineTranslationSettled()
        return model
    }
}
#endif
