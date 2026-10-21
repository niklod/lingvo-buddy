import Foundation

/// One JSON source file of dictionary data (the sample, or one generated batch).
///
/// Format: `{"meta": {"key": "value"}, "entries": [{"headword", "rank", "pos", "ipa",
/// "example", "synonym_group", "tier", "translations": {"ru": ["…"]}}]}`.
/// `meta` is optional.
public struct DictionarySource: Sendable, Equatable {
    public let meta: [String: String]
    public let entries: [DictionaryEntry]

    public init(meta: [String: String], entries: [DictionaryEntry]) {
        self.meta = meta
        self.entries = entries
    }

    public static func decode(json data: Data) throws -> DictionarySource {
        do {
            let file = try JSONDecoder().decode(SourceFile.self, from: data)
            return DictionarySource(meta: file.meta ?? [:], entries: try file.entries.map { try $0.entry() })
        } catch let error as LingvoCoreError {
            throw error
        } catch {
            throw LingvoCoreError.invalidDictionary("cannot decode JSON source: \(error)")
        }
    }

    /// Joins several sources into one; later `meta` values win on equal keys.
    public static func merged(_ sources: [DictionarySource]) -> DictionarySource {
        DictionarySource(
            meta: sources.reduce(into: [:]) { result, source in result.merge(source.meta) { _, new in new } },
            entries: sources.flatMap(\.entries)
        )
    }
}

private struct SourceFile: Decodable {
    let meta: [String: String]?
    let entries: [SourceEntry]
}

private struct SourceEntry: Decodable {
    let headword: String
    let rank: Int
    let pos: String
    let ipa: String?
    let example: String?
    let synonymGroup: String?
    let tier: String
    let translations: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case headword, rank, pos, ipa, example, tier, translations
        case synonymGroup = "synonym_group"
    }

    func entry() throws -> DictionaryEntry {
        guard let partOfSpeech = PartOfSpeech(rawValue: pos) else {
            throw LingvoCoreError.invalidDictionary("\(headword): unknown part of speech \"\(pos)\"")
        }
        guard let parsedTier = DictionaryTier(rawValue: tier) else {
            throw LingvoCoreError.invalidDictionary("\(headword): unknown tier \"\(tier)\"")
        }
        return DictionaryEntry(
            headword: headword,
            rank: rank,
            partOfSpeech: partOfSpeech,
            ipa: ipa,
            example: example,
            synonymGroup: synonymGroup,
            tier: parsedTier,
            translations: try parsedTranslations()
        )
    }

    private func parsedTranslations() throws -> [Language: [String]] {
        try translations.reduce(into: [:]) { result, pair in
            guard let language = Language(rawValue: pair.key) else {
                throw LingvoCoreError.invalidDictionary("\(headword): unknown language \"\(pair.key)\"")
            }
            result[language] = pair.value
        }
    }
}
