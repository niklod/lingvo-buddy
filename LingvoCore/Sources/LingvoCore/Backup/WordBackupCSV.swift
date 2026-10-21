import Foundation

/// The CSV file: a header line with column names, then one line per word.
enum WordBackupCSV {
    static let maxBytes = Tutor.maxCSVImportBytes
    /// Excel reads a CSV without it as a legacy encoding and garbles Cyrillic.
    private static let byteOrderMark = "\u{FEFF}"

    static func encode(_ rows: [WordBackupRow]) -> Data {
        let header = WordBackupColumn.allCases.map(\.rawValue)
        return Data((byteOrderMark + CSVCodec.encode([header] + rows.map(\.fields))).utf8)
    }

    /// Columns may come in any order; only `headword` is required.
    static func decode(_ data: Data, now: Date) throws(CSVImportError) -> [WordBackupRow] {
        guard data.count <= maxBytes else { throw .fileTooLarge(limitBytes: maxBytes) }
        guard var text = String(data: data, encoding: .utf8) else { throw .notUTF8 }
        if text.hasPrefix(byteOrderMark) {
            text.removeFirst()
        }
        let records = try CSVCodec.decode(text)
        guard let header = records.first else { throw .empty }
        let columns = try self.columns(in: header)
        var seen = Set<String>()
        return try records.dropFirst().map { record throws(CSVImportError) in
            guard record.fields.count == columns.count else {
                throw .wrongFieldCount(line: record.line, expected: columns.count, found: record.fields.count)
            }
            let reader = CSVFieldReader(line: record.line, values: Dictionary(uniqueKeysWithValues: zip(columns, record.fields)))
            let row = try WordBackupRow(reading: reader, now: now)
            guard seen.insert(row.headword).inserted else {
                throw .duplicateWord(line: record.line, headword: row.headword)
            }
            return row
        }
    }

    private static func columns(in header: CSVRecord) throws(CSVImportError) -> [WordBackupColumn] {
        let names = header.fields.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let unknown = names.filter { WordBackupColumn(rawValue: $0) == nil }
        guard unknown.isEmpty else { throw .unknownColumns(unknown) }
        let repeated = Dictionary(grouping: names, by: { $0 }).filter { $1.count > 1 }.keys.sorted()
        guard repeated.isEmpty else { throw .duplicateColumns(repeated) }
        guard names.contains(WordBackupColumn.headword.rawValue) else {
            throw .missingColumns([WordBackupColumn.headword.rawValue])
        }
        return names.compactMap(WordBackupColumn.init(rawValue:))
    }
}
