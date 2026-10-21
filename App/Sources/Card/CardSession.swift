import LingvoCore
import Observation

/// One shown card from appearance to "Next": sends the answer to the tutor once
/// and keeps the result so the options stop reacting.
@MainActor
@Observable
final class CardSession {
    private(set) var state: QuizCardState
    private let tutor: Tutor
    private let onError: (Error) -> Void

    init(card: Card, tutor: Tutor, onError: @escaping (Error) -> Void) {
        self.state = QuizCardState(card: card, answer: nil)
        self.tutor = tutor
        self.onError = onError
    }

    func pick(_ index: Int) {
        submit(pickedIndex: index) { try tutor.answer(state.card, choice: index) }
    }

    func dontKnow() {
        submit(pickedIndex: nil) { try tutor.dontKnow(state.card) }
    }

    private func submit(pickedIndex: Int?, _ operation: () throws -> AnswerResult) {
        guard !state.isAnswered else { return }
        do {
            let result = try operation()
            state = QuizCardState(card: state.card, answer: .init(pickedIndex: pickedIndex, result: result))
        } catch {
            onError(error)
        }
    }
}
