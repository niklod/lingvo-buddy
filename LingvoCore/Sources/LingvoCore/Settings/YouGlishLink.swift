import Foundation

/// The accent filter of the YouGlish link on the card. The raw value is the
/// stored setting; YouGlish has more accents, but they have too few clips to
/// help a learner.
public enum YouGlishAccent: String, Sendable, CaseIterable {
    case all
    case us
    case uk
    case aus
}

/// The YouGlish page that plays real videos with the headword in them.
public enum YouGlishLink {
    private static let base = "https://youglish.com/pronounce/"

    /// The characters `encodeURIComponent` keeps, so that the link matches
    /// the design. A slash or "?" in a headword must not change the path.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
    )

    public static func url(for headword: String, accent: YouGlishAccent) -> URL? {
        let phrase = headword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty,
              let encoded = phrase.addingPercentEncoding(withAllowedCharacters: unreserved)
        else { return nil }
        let suffix = accent == .all ? "" : "/" + accent.rawValue
        return URL(string: base + encoded + "/english" + suffix)
    }
}
