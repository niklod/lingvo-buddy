import Foundation

/// Typed values of one CSV line, with errors that name the line and column.
/// Values are trimmed; an empty value reads as `nil`.
struct CSVFieldReader {
    let line: Int
    let values: [WordBackupColumn: String]

    func text(_ column: WordBackupColumn) -> String? {
        let value = values[column]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    func text(_ column: WordBackupColumn, limit: Int) throws(CSVImportError) -> String? {
        guard let value = text(column) else { return nil }
        guard value.count <= limit else { throw .tooLong(line: line, column: column.rawValue, limit: limit) }
        return value
    }

    func required(_ column: WordBackupColumn, limit: Int) throws(CSVImportError) -> String {
        guard let value = try text(column, limit: limit) else {
            throw .missingValue(line: line, column: column.rawValue)
        }
        return value
    }

    func int(_ column: WordBackupColumn, in range: ClosedRange<Int>) throws(CSVImportError) -> Int? {
        try parse(column, expected: "a whole number from \(range.lowerBound) to \(range.upperBound)") {
            Int($0).flatMap { range.contains($0) ? $0 : nil }
        }
    }

    func bool(_ column: WordBackupColumn) throws(CSVImportError) -> Bool? {
        try parse(column, expected: "1 or 0") { value in
            switch value.lowercased() {
            case "1", "true": true
            case "0", "false": false
            default: nil
            }
        }
    }

    func date(_ column: WordBackupColumn) throws(CSVImportError) -> Date? {
        try parse(column, expected: "a time like 2026-10-15T09:30:00.000Z") { CSVTimestamp(iso: $0)?.date }
    }

    func choice<Value: RawRepresentable & CaseIterable>(
        _ column: WordBackupColumn,
        of type: Value.Type
    ) throws(CSVImportError) -> Value? where Value.RawValue == String {
        let names = Value.allCases.map(\.rawValue).joined(separator: ", ")
        return try parse(column, expected: names) { Value(rawValue: $0) }
    }

    private func parse<Value>(
        _ column: WordBackupColumn,
        expected: String,
        _ transform: (String) -> Value?
    ) throws(CSVImportError) -> Value? {
        guard let value = text(column) else { return nil }
        guard let parsed = transform(value) else {
            throw .invalidValue(line: line, column: column.rawValue, value: value, expected: expected)
        }
        return parsed
    }
}
