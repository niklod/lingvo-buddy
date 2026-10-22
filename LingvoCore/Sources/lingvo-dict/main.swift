import Foundation
import LingvoCore

let usage = """
    Usage: lingvo-dict check <dictionary.sqlite> [<extended-dictionary.sqlite>]
      Opens a built dictionary read-only, as the app does, checks its schema
      against the app's contract and prints the first quiz card. With the extended
      dictionary it checks that file's schema, licence note and entries too.
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("lingvo-dict: \(message)\n".utf8))
    exit(1)
}

/// Proves that a dictionary from any builder (for example tools/dictionary) works with the app's reader.
func runCheck(_ arguments: [String]) throws {
    guard (1...2).contains(arguments.count) else {
        fail("check needs a dictionary file and optionally an extended dictionary file\n\(usage)")
    }
    let store = try DictionaryStore.open(at: URL(fileURLWithPath: arguments[0]))
    let drift = try store.schemaDrift()
    guard drift.isEmpty else {
        fail("the schema differs from LingvoCore's DictionarySchema in:\n\(drift.joined(separator: "\n"))")
    }
    guard let license = try store.meta()["license"], !license.isEmpty else {
        fail("meta has no license")
    }
    let extended = try arguments.dropFirst().first.map { try checkExtended(at: $0) }
    let tutor = try Tutor(dictionary: store, userDatabase: try UserDatabase.inMemory(), extendedDictionary: extended)
    guard let card = try tutor.nextCard().card else {
        fail("no quiz card in \(arguments[0])")
    }
    guard card.ipa != nil, card.example != nil, card.options.count == 4 else {
        fail("card for \(card.headword) misses ipa, example or options")
    }
    print("lingvo-dict: first card \(card.headword) \(card.ipa ?? "") \(card.options) - \(card.example ?? "")")
    try checkTiers(tutor)
    if extended != nil {
        try checkExtendedPreview(tutor)
    }
}

/// The extended dictionary has to open like the app opens it, match the app's schema and carry its licence note.
func checkExtended(at path: String) throws -> ExtendedDictionary {
    let extended = try ExtendedDictionary.open(at: URL(fileURLWithPath: path))
    let drift = try extended.schemaDrift()
    guard drift.isEmpty else {
        fail("the extended schema differs from LingvoCore's ExtendedSchema in:\n\(drift.joined(separator: "\n"))")
    }
    guard let license = try extended.meta()["license"], license.contains("CC BY-SA") else {
        fail("extended meta has no CC BY-SA license note")
    }
    let counts = try extended.counts()
    guard counts.english > 0, counts.russian > 0 else {
        fail("the extended dictionary is empty: \(counts)")
    }
    print("lingvo-dict: extended dictionary has \(counts.english) English and \(counts.russian) Russian entries")
    return extended
}

/// A word that only the extended dictionary has must reach quick add with translations.
func checkExtendedPreview(_ tutor: Tutor) throws {
    guard let preview = try tutor.quickAddPreview("petrichor"), preview.lookup == nil,
          !preview.candidates[0].translations.isEmpty
    else {
        fail("quick add found no extended translation for \"petrichor\"")
    }
    print("lingvo-dict: petrichor \(preview.candidates[0].translations)")
}

/// Quick add must fill a lookup-tier word ("reluctant" in the spec) and tell it is outside Top‑1000.
func checkTiers(_ tutor: Tutor) throws {
    let progress = try tutor.tierProgress()
    guard progress.tier == .top1000, progress.total > 0 else {
        fail("a fresh learner should start on Top-1000 with card words, got \(progress)")
    }
    guard let found = try tutor.lookup("reluctant") else {
        fail("lookup of \"reluctant\" found nothing")
    }
    guard found.entry.ipa != nil, found.entry.primaryRussian != nil, found.membership == .outside(.top1000) else {
        fail("lookup of \"reluctant\" misses ipa or translation, or is not outside Top-1000: \(found)")
    }
    print("lingvo-dict: Top-1000 has \(progress.total) card words; reluctant #\(found.entry.rank) \(found.membership)")
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "check":
        try runCheck(Array(arguments.dropFirst()))
    default:
        fail(usage)
    }
} catch {
    fail(error.localizedDescription)
}
