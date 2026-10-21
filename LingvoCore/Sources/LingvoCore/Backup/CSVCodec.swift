import Foundation

/// One CSV record and the file line it starts on (for error messages).
struct CSVRecord: Sendable, Equatable {
    let line: Int
    let fields: [String]
}

/// RFC 4180 CSV: comma separated, fields with commas, quotes or line breaks in
/// double quotes, a quote inside quotes doubled. Spreadsheets write CRLF, LF or CR.
enum CSVCodec {
    static func encode(_ rows: [[String]]) -> String {
        rows.map { $0.map(quoted).joined(separator: ",") + "\r\n" }.joined()
    }

    /// Blank lines are skipped.
    static func decode(_ text: String) throws(CSVImportError) -> [CSVRecord] {
        var parser = Parser()
        for character in text {
            try parser.consume(character)
        }
        return try parser.finish()
    }

    private static func quoted(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

private struct Parser {
    private enum State {
        case fieldStart
        case unquoted
        case quoted
        /// A quote inside a quoted field: the field ends, or it was the first of a doubled quote.
        case quoteInQuoted
    }

    private var state = State.fieldStart
    private var line = 1
    private var recordLine = 1
    private var field = ""
    private var fields: [String] = []
    private var records: [CSVRecord] = []

    mutating func consume(_ character: Character) throws(CSVImportError) {
        switch state {
        case .fieldStart, .unquoted:
            try consumeOutsideQuotes(character)
        case .quoted:
            if character == "\"" {
                state = .quoteInQuoted
            } else {
                field.append(character)
                if character.isNewline { line += 1 }
            }
        case .quoteInQuoted:
            if character == "\"" {
                field.append(character)
                state = .quoted
            } else if character == "," || character.isNewline {
                try consumeOutsideQuotes(character)
            } else {
                throw .misplacedQuote(line: line)
            }
        }
    }

    mutating func finish() throws(CSVImportError) -> [CSVRecord] {
        if state == .quoted {
            throw .unterminatedQuote(line: recordLine)
        }
        if state != .fieldStart || !fields.isEmpty {
            endRecord()
        }
        return records
    }

    private mutating func consumeOutsideQuotes(_ character: Character) throws(CSVImportError) {
        switch character {
        case ",":
            fields.append(field)
            field = ""
            state = .fieldStart
        case "\"":
            guard state == .fieldStart else { throw .misplacedQuote(line: line) }
            state = .quoted
        case _ where character.isNewline:
            endRecord()
            line += 1
            recordLine = line
        default:
            field.append(character)
            state = .unquoted
        }
    }

    private mutating func endRecord() {
        fields.append(field)
        if fields != [""] {
            records.append(CSVRecord(line: recordLine, fields: fields))
        }
        field = ""
        fields = []
        state = .fieldStart
    }
}
