import Foundation
import LingvoCore

let usage = """
    Usage: lingvo-dict build --out <dictionary.sqlite> <source.json> [<source.json> ...]
      Merges JSON dictionary sources and writes the bundled SQLite dictionary.
    Usage: lingvo-dict check <dictionary.sqlite>
      Opens a built dictionary read-only, as the app does, and prints the first quiz card.
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("lingvo-dict: \(message)\n".utf8))
    exit(1)
}

func runBuild(_ arguments: [String]) throws {
    guard let outFlag = arguments.firstIndex(of: "--out"), arguments.indices.contains(outFlag + 1) else {
        fail("missing --out <path>\n\(usage)")
    }
    let output = URL(fileURLWithPath: arguments[outFlag + 1])
    let inputs = arguments.enumerated()
        .filter { $0.offset != outFlag && $0.offset != outFlag + 1 }
        .map { URL(fileURLWithPath: $0.element) }
    guard !inputs.isEmpty else {
        fail("no source files\n\(usage)")
    }
    let sources = try inputs.map { try DictionarySource.decode(json: Data(contentsOf: $0)) }
    let merged = DictionarySource.merged(sources)
    try FileManager.default.createDirectory(
        at: output.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try DictionaryBuilder.buildFile(from: merged, at: output)
    print("lingvo-dict: wrote \(merged.entries.count) entries to \(output.path)")
}

/// Proves that a dictionary from any builder (for example tools/dictionary) works with the app's reader.
func runCheck(_ arguments: [String]) throws {
    guard arguments.count == 1 else {
        fail("check needs one dictionary file\n\(usage)")
    }
    let store = try DictionaryStore.open(at: URL(fileURLWithPath: arguments[0]))
    guard let license = try store.meta()["license"], !license.isEmpty else {
        fail("meta has no license")
    }
    let tutor = try Tutor(dictionary: store, userDatabase: try UserDatabase.inMemory())
    guard let card = try tutor.nextCard().card else {
        fail("no quiz card in \(arguments[0])")
    }
    guard card.ipa != nil, card.example != nil, card.options.count == 4 else {
        fail("card for \(card.headword) misses ipa, example or options")
    }
    print("lingvo-dict: first card \(card.headword) \(card.ipa ?? "") \(card.options) - \(card.example ?? "")")
    try checkTiers(tutor)
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
    case "build":
        try runBuild(Array(arguments.dropFirst()))
    case "check":
        try runCheck(Array(arguments.dropFirst()))
    default:
        fail(usage)
    }
} catch {
    fail(error.localizedDescription)
}
