import Foundation
import GRDB

extension DictionaryStore {
    /// Schema statements in which this file and `DictionarySchema` differ;
    /// empty when they match. The file comes from tools/dictionary, so this is
    /// the check that keeps the two writers of the contract in step.
    public func schemaDrift() throws -> [String] {
        try ReadOnlyDictionaryFile.schemaDrift(of: reader, contract: DictionarySchema.create(in:))
    }

    /// Translations whose stored `norm` is not `RussianText.normalized(text)`, as "text: norm"; empty when
    /// all match. Russian input finds words only through `norm`, so tools/dictionary must normalise
    /// exactly as the app does.
    public func normalizationDrift() throws -> [String] {
        try reader.read { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT text, norm FROM translations")
            var drift: [String] = []
            while let row = try rows.next() {
                let text: String = row["text"]
                let norm: String = row["norm"]
                if norm != RussianText.normalized(text) { drift.append("\(text): \(norm)") }
            }
            return drift
        }
    }
}
