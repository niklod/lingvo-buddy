import Foundation

/// String cutting for `SystemEntry.parse`: pure functions over the text of one entry.
enum SystemEntryText {
    /// Where the first sense ends: the next sense, a section of the entry, or a numbered sense.
    private static let senseEnds = [" • ", " ORIGIN ", " DERIVATIVES ", " PHRASES ", " PHRASAL VERBS ", " USAGE "]

    /// A new numbered sense follows a finished sentence: "... ski run. 2 pass or cause ...".
    private static var nextNumberedSense: Regex<Substring> { /[.!?]\s\d{1,2}\s/ }

    private static var senseNumber: Regex<Substring> { /^\d{1,2}\s+/ }

    /// Region and register labels in front of a definition ("North American English informal").
    private static var usageLabel: Regex<Substring> {
        #/
            (?x)
            ^ (?: (?:mainly|chiefly|mostly|especially|also|originally|now) \s+ )?
            (?:
                (?: North\sAmerican | British | US | American | Australian\sand\sNew\sZealand | Australian
                  | New\sZealand | Irish | Scottish\sand\sNorthern | Scottish | Scots | West\sIndian
                  | South\sAfrican | Indian | Canadian | Caribbean | Welsh ) \s+ English
                | informal | formal | archaic | literary | humorous | humorously | dated | rare | slang
                | vulgar | offensive | derogatory | technical | historical | poetic | ironic | euphemistic
                | dialect | disapproving | approving | figurative | figuratively | old-fashioned
            ) \b \s*
        /#
    }

    /// Longest first: "modal verb" must win over "verb" at another position.
    private static let partsOfSpeech: [(name: String, value: PartOfSpeech)] = [
        ("noun", .noun), ("verb", .verb), ("modal verb", .verb), ("auxiliary verb", .verb),
        ("adjective", .adjective), ("adverb", .adverb), ("pronoun", .pronoun),
        ("preposition", .preposition), ("conjunction", .conjunction), ("determiner", .determiner),
        ("number", .numeral), ("exclamation", .interjection), ("interjection", .interjection),
        ("abbreviation", .other), ("prefix", .other), ("suffix", .other), ("combining form", .other),
        ("symbol", .other), ("contraction", .other),
    ].sorted { $0.name.count > $1.name.count }

    /// The text between the first two bars and the text after them; `nil` without a closing bar.
    static func firstBarred(in text: String) -> (inside: String, after: String)? {
        guard let open = text.firstIndex(of: "|") else { return nil }
        let afterOpen = text.index(after: open)
        guard let close = text[afterOpen...].firstIndex(of: "|") else { return nil }
        let inside = text[afterOpen..<close].trimmingCharacters(in: .whitespaces)
        let after = text[text.index(after: close)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (inside, after)
    }

    /// The part of speech that starts the text after the pronunciation, and what follows it.
    /// Forms in parentheses ("(runs) (past; ran | ran |)") may stand in between.
    static func partOfSpeech(in text: String) -> (PartOfSpeech?, String) {
        var rest = text
        while let stripped = droppingLeadingGroup(rest, open: "(", close: ")") { rest = stripped }
        let lowered = rest.lowercased()
        for part in partsOfSpeech where lowered.hasPrefix(part.name) {
            let end = rest.index(rest.startIndex, offsetBy: part.name.count)
            guard end == rest.endIndex || !rest[end].isLetter else { continue }
            return (part.value, String(rest[end...]).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return (nil, rest)
    }

    /// The first sense: its definition and the example after its colon.
    static func firstSense(of body: String) -> (definition: String?, example: String?) {
        let sense = cutAtSenseEnd(strippingLeadingNotes(body))
        guard let colon = sense.range(of: ": ") else {
            return (definition(sense), nil)
        }
        return (definition(String(sense[..<colon.lowerBound])), example(String(sense[colon.upperBound...])))
    }

    /// Sense numbers, bracketed grammar notes, qualifiers in parentheses and usage labels
    /// are not part of the definition.
    private static func strippingLeadingNotes(_ text: String) -> String {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while true {
            let next: String
            if let match = rest.prefixMatch(of: senseNumber) {
                next = String(rest[match.range.upperBound...])
            } else if let match = rest.prefixMatch(of: usageLabel) {
                next = String(rest[match.range.upperBound...])
            } else if let stripped = droppingLeadingGroup(rest, open: "[", close: "]")
                ?? droppingLeadingGroup(rest, open: "(", close: ")") {
                next = stripped
            } else {
                return rest
            }
            rest = next.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func cutAtSenseEnd(_ text: String) -> String {
        var end = text.endIndex
        for marker in senseEnds {
            if let range = text.range(of: marker), range.lowerBound < end { end = range.lowerBound }
        }
        if let match = text.firstMatch(of: nextNumberedSense) {
            // The sentence's own punctuation stays with the sense.
            let kept = text.index(after: match.range.lowerBound)
            if kept < end { end = kept }
        }
        return String(text[..<end])
    }

    private static func definition(_ text: String) -> String? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.last == "." || text.last == ";" { text.removeLast() }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// The text after the colon: a bracketed note ("[with infinitive] :") is not part of it, and
    /// the next example after a bar is another sentence.
    private static func example(_ text: String) -> String? {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let stripped = droppingLeadingGroup(rest, open: "[", close: "]") {
            rest = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            if rest.hasPrefix(":") { rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        if let bar = rest.range(of: " | ") { rest = String(rest[..<bar.lowerBound]) }
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    /// The text after a group that starts the string, with nested groups counted; `nil` when none does.
    private static func droppingLeadingGroup(_ text: String, open: Character, close: Character) -> String? {
        guard text.first == open else { return nil }
        var depth = 0
        for index in text.indices {
            if text[index] == open { depth += 1 }
            if text[index] == close { depth -= 1 }
            if depth == 0 { return String(text[text.index(after: index)...]) }
        }
        return nil
    }
}
