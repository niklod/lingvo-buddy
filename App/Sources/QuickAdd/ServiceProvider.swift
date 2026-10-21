import AppKit

/// The "Add to LingvoBuddy" Services item (Info.plist `NSServices`, message
/// `addToLingvoBuddy`). It opens quick add prefilled with the selected text.
@MainActor
final class ServiceProvider: NSObject {
    /// A longer selection is a sentence: it goes to "Where I saw it", not to the word field.
    static let maxWordsInWord = 3

    private let openQuickAdd: (_ word: String?, _ example: String) -> Void

    init(openQuickAdd: @escaping (_ word: String?, _ example: String) -> Void) {
        self.openQuickAdd = openQuickAdd
    }

    @objc func addToLingvoBuddy(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            error.pointee = String(localized: "No text is selected.") as NSString
            return
        }
        let words = text.split(whereSeparator: \.isWhitespace)
        if words.count <= Self.maxWordsInWord {
            openQuickAdd(words.joined(separator: " "), "")
        } else {
            openQuickAdd(nil, text)
        }
    }
}
