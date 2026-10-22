import Foundation
import LingvoCore
import Testing

@Suite("Quick add example")
struct QuickAddExampleTests {
    static let provideExample = "The hotel provides free breakfast."

    static func learner() throws -> Learner {
        try Learner(settings: LearningSettings(direction: .enToRu))
    }

    @Test("the preview shows the dictionary example of the word")
    func previewShowsExample() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview(" Provide "))

        #expect(preview.example == Self.provideExample)
    }

    @Test("the preview has no example for a word without one or a word the dictionary lacks")
    func previewWithoutExample() throws {
        let learner = try Self.learner()

        let lookupTier = try #require(try learner.tutor.quickAddPreview("reluctant"))
        let unknown = try #require(try learner.tutor.quickAddPreview("Kubernetes"))

        #expect(lookupTier.example == nil)
        #expect(unknown.example == nil)
    }

    @Test("an empty \"Where I saw it\" field puts the previewed example on the card")
    func emptyFieldKeepsDictionaryExample() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("provide"))
        _ = try learner.tutor.addMyWord(NewMyWord(text: "provide", translation: "предоставлять", example: "  "))
        let card = try learner.nextCard()

        #expect(card.headword == "provide")
        #expect(card.example == preview.example)
        #expect(card.example == Self.provideExample)
    }

    @Test("own \"Where I saw it\" text replaces the previewed example on the card")
    func ownTextReplacesExample() throws {
        let learner = try Self.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(
            text: "provide",
            translation: "предоставлять",
            example: "We provide the data."
        ))
        let card = try learner.nextCard()

        #expect(card.headword == "provide")
        #expect(card.example == "We provide the data.")
    }
}
