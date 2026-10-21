import Foundation
import LingvoCore
import Observation

/// What the Dictionary window needs from the tutor.
protocol WordListStore: Sendable {
    func wordList(_ list: WordList, search: String) throws -> WordListPage
    func markLearned(_ headword: String) throws
    func resetProgress(_ headword: String) throws
    func deleteWord(_ headword: String) throws
    func editTranslation(_ headword: String, to translation: String) throws
}

extension Tutor: WordListStore {}

enum RowAction {
    case markLearned
    case resetProgress
    case delete
    case editTranslation(String)
}

/// The selected list, the search text and the page the tutor returned for them.
/// Every change goes through the tutor and reloads, so the table never shows
/// a state the database does not have.
@MainActor
@Observable
final class DictionaryModel {
    var list: WordList = .learning {
        didSet { if list != oldValue { reload() } }
    }
    var search = "" {
        didSet { if search != oldValue { reload() } }
    }
    private(set) var page = WordListPage(
        counts: Dictionary(uniqueKeysWithValues: WordList.allCases.map { ($0, 0) }),
        queueTier: .top1000,
        rows: []
    )
    /// When the page was read: the "12 min" ages count from here.
    private(set) var loadedAt = Date()

    @ObservationIgnored private let store: any WordListStore
    @ObservationIgnored private let errors: ErrorPresenter?
    @ObservationIgnored private let now: () -> Date

    init(store: any WordListStore, errors: ErrorPresenter?, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.errors = errors
        self.now = now
        reload()
    }

    func reload() {
        do {
            page = try store.wordList(list, search: search)
            loadedAt = now()
        } catch {
            errors?.show(error)
        }
    }

    func perform(_ action: RowAction, on row: WordRow) {
        do {
            switch action {
            case .markLearned: try store.markLearned(row.headword)
            case .resetProgress: try store.resetProgress(row.headword)
            case .delete: try store.deleteWord(row.headword)
            case .editTranslation(let text): try store.editTranslation(row.headword, to: text)
            }
        } catch {
            errors?.show(error)
        }
        reload()
    }

    /// The search text, for "+ Word" when the search found nothing: the learner
    /// was most likely looking for a word they want to add.
    var unmatchedSearch: String? {
        let text = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || !page.rows.isEmpty ? nil : text
    }
}
