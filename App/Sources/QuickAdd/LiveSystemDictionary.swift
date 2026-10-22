import CoreServices
import Foundation
import LingvoCore

/// The macOS dictionaries through the public Dictionary Services call. It uses the default dictionary
/// set the learner has turned on, so it needs no private API and works in the App Sandbox.
struct LiveSystemDictionary: SystemDictionary {
    /// Any word: the call only has to load the dictionaries.
    private static let warmUpWord = "word"

    func definition(of word: String) -> String? {
        let text = word as NSString
        return DCSCopyTextDefinition(nil, text, CFRangeMake(0, text.length))?.takeRetainedValue() as String?
    }

    /// The first call loads the dictionaries (about 23 ms). Quick add asks on the main thread per
    /// keystroke, so one call off it at launch keeps that cost out of the first lookup.
    static func warmUp() {
        Task.detached(priority: .utility) {
            _ = LiveSystemDictionary().definition(of: warmUpWord)
        }
    }
}
