import Foundation

/// The CSV file: a header line with column names, then one line per word.
enum WordBackupCSV {
    /// Excel reads a CSV without it as a legacy encoding and garbles Cyrillic.
    private static let byteOrderMark = "\u{FEFF}"

    static func encode(_ rows: [WordBackupRow]) -> Data {
        let header = WordBackupColumn.allCases.map(\.rawValue)
        return Data((byteOrderMark + CSVCodec.encode([header] + rows.map(\.fields))).utf8)
    }

    /// Columns may come in any order; only `headword` is required.
    static func decode(_ data: Data, now: Date, headwords: ImportHeadwords) throws -> [WordBackupRow] {
        let records = try records(in: data)
        guard let header = records.first else { throw CSVImportError.empty }
        guard records.count - 1 <= Tutor.maxCSVImportRows else {
            throw CSVImportError.tooManyRows(limit: Tutor.maxCSVImportRows)
        }
        let columns = try self.columns(in: header)
        var headwords = headwords
        return try records.dropFirst().map { record in
            guard record.fields.count == columns.count else {
                throw CSVImportError.wrongFieldCount(line: record.line, expected: columns.count, found: record.fields.count)
            }
            let reader = CSVFieldReader(line: record.line, values: Dictionary(uniqueKeysWithValues: zip(columns, record.fields)))
            let typed = try reader.required(.headword, limit: NewMyWord.maxWordLength)
            let headword = try headwords.resolve(typed, line: record.line, isMyWord: reader.text(.translation) != nil)
            return try WordBackupRow(reading: reader, headword: headword, now: now)
        }
    }

    private static func records(in data: Data) throws(CSVImportError) -> [CSVRecord] {
        guard data.count <= Tutor.maxCSVImportBytes else { throw .fileTooLarge(limitBytes: Tutor.maxCSVImportBytes) }
        guard var text = String(data: data, encoding: .utf8) else { throw .notUTF8 }
        if text.hasPrefix(byteOrderMark) {
            text.removeFirst()
        }
        return try CSVCodec.decode(text)
    }

    private static func columns(in header: CSVRecord) throws(CSVImportError) -> [WordBackupColumn] {
        if header.fields.count == 1, header.fields[0].contains(";") {
            throw .semicolonSeparated
        }
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
