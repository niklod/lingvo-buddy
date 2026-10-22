import Foundation

/// The macOS dictionary as quick add sees it: one word in, the raw entry text out. The app provides
/// the live implementation; the core only parses the text, so tests need no system service.
public protocol SystemDictionary: Sendable {
    /// `nil` when the dictionary has nothing for the word.
    func definition(of word: String) -> String?
}
