import Foundation
import LingvoCore
import Testing

@Suite("YouGlish pronunciation link")
struct YouGlishLinkTests {
    @Test("all accents link to the plain English page")
    func allAccents() {
        let url = YouGlishLink.url(for: "although", accent: .all)

        #expect(url?.absoluteString == "https://youglish.com/pronounce/although/english")
    }

    @Test("each accent adds its YouGlish code", arguments: [
        (YouGlishAccent.us, "us"), (.uk, "uk"), (.aus, "aus"),
    ])
    func accentSuffix(accent: YouGlishAccent, code: String) {
        let url = YouGlishLink.url(for: "although", accent: accent)

        #expect(url?.absoluteString == "https://youglish.com/pronounce/although/english/\(code)")
    }

    @Test("a phrase goes as one encoded path segment")
    func phrase() {
        let url = YouGlishLink.url(for: "give up", accent: .all)

        #expect(url?.absoluteString == "https://youglish.com/pronounce/give%20up/english")
    }

    @Test("a slash or a question mark cannot break the path")
    func reservedCharacters() {
        let url = YouGlishLink.url(for: "and/or?", accent: .all)

        #expect(url?.absoluteString == "https://youglish.com/pronounce/and%2For%3F/english")
    }

    @Test("an empty headword has no link")
    func emptyHeadword() {
        #expect(YouGlishLink.url(for: "  ", accent: .all) == nil)
    }
}
