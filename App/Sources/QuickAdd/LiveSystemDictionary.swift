import CoreServices
import Foundation
import LingvoCore

/// The macOS dictionaries through the public Dictionary Services call. It uses the default dictionary
/// set the learner has turned on, so it needs no private API and works in the App Sandbox.
struct LiveSystemDictionary: SystemDictionary {
    func definition(of word: String) -> String? {
        let text = word as NSString
        return DCSCopyTextDefinition(nil, text, CFRangeMake(0, text.length))?.takeRetainedValue() as String?
    }
}
