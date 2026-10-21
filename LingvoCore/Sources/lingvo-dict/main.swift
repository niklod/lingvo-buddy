import Foundation
import LingvoCore

let usage = """
    Usage: lingvo-dict build --out <dictionary.sqlite> <source.json> [<source.json> ...]
      Merges JSON dictionary sources and writes the bundled SQLite dictionary.
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

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "build":
        try runBuild(Array(arguments.dropFirst()))
    default:
        fail(usage)
    }
} catch {
    fail(error.localizedDescription)
}
