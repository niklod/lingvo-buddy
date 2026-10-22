#if DEBUG
import LingvoCore
import SwiftUI

/// Quick add with data from the system dictionary. The texts are what `DCSCopyTextDefinition` returned on macOS.
@MainActor
enum SystemDictionarySnapshots {
    // swiftlint:disable:next line_length
    private static let mumpsimus = "mumpsimus mump·si·mus | ˈməm(p)səməs | noun (plural mumpsimuses) a traditional custom or notion adhered to although shown to be unreasonable. • a person who obstinately adheres to unreasonable customs or notions. ORIGIN mid 16th century: erroneously for Latin sumpsimus in quod in ore sumpsimus."
    // swiftlint:disable:next line_length
    static let codswallop = "codswallop cods·wal·lop | ˈkädzˌwäləp | noun British English informal nonsense: I think that's a right load of old codswallop. ORIGIN 1920s: probably an alteration of cod walloper."

    static var states: [SnapshotState] {
        [
            // The machine translation is the only translation: the learner can judge it with the hint.
            state("quick_add_system_machine", text: "mumpsimus", system: mumpsimus, answer: .translated("Сурка")),
            state("quick_add_system_extended", text: "codswallop", system: codswallop, extended: QuickAddSnapshots.codswallop),
            state("quick_add_system_none", text: "kubernetes", system: nil),
        ]
    }

    private static func state(
        _ name: String,
        text: String,
        system: String?,
        extended: ExtendedEntry? = nil,
        answer: MachineTranslation? = nil
    ) -> SnapshotState {
        QuickAddSnapshots.panelState(name) {
            let entry = system.flatMap { SystemEntry.parse($0, for: text) }
            let model = QuickAddModel(text: text, translator: answer.map(FakeMachineTranslator.init(answer:))) { query in
                QuickAddPreview(headword: query, lookup: nil, standing: .notAdded, extended: extended, system: entry)
            }
            await model.machineTranslationSettled()
            return model
        }
    }
}
#endif
