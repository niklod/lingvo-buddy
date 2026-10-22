import Foundation

/// What quick add reads from the text of a system dictionary entry (New Oxford American style:
/// "word syl·la·bles | pronunciation | noun [label] definition: example. • next sense ... ORIGIN ...").
/// A field the text does not give clearly stays `nil`.
public struct SystemEntry: Sendable, Equatable {
    /// An example longer than this is a quotation, not a short example for the card.
    static let maxExampleLength = NewMyWord.maxExampleLength

    /// American IPA in slashes, converted from the dictionary's own notation.
    public let ipa: String?
    public let partOfSpeech: PartOfSpeech?
    /// The first definition without labels such as "informal", for the definition hint.
    public let definition: String?
    /// The text after the colon of the first sense.
    public let example: String?

    public init(
        ipa: String? = nil,
        partOfSpeech: PartOfSpeech? = nil,
        definition: String? = nil,
        example: String? = nil
    ) {
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.example = example
    }

    /// `nil` when the text is not the entry of `word` or gives no field at all. The dictionary
    /// answers with its closest entry ("colour" gives "unicolor"), whose data would be wrong.
    public static func parse(_ text: String, for word: String) -> SystemEntry? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, text.lowercased().hasPrefix(word.lowercased() + " ") else { return nil }
        guard let (pronunciation, afterBars) = SystemEntryText.firstBarred(in: text) else { return nil }
        let (partOfSpeech, body) = SystemEntryText.partOfSpeech(in: afterBars)
        let sense = partOfSpeech == nil ? nil : SystemEntryText.firstSense(of: body)
        let entry = SystemEntry(
            ipa: OxfordPronunciation.ipa(pronunciation),
            partOfSpeech: partOfSpeech,
            definition: sense?.definition,
            example: sense?.example.flatMap { $0.count <= maxExampleLength ? $0 : nil }
        )
        return entry == SystemEntry() ? nil : entry
    }
}
