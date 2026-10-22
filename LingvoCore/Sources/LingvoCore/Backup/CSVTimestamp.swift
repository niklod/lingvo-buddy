import Foundation

/// A moment at millisecond precision, the precision of the user database.
///
/// Conversions use whole milliseconds, not `DateFormatter`: a formatter
/// truncates, and a `Date` rebuilt from milliseconds can sit a hair below its
/// millisecond, so an export → import → export would lose 1 ms per pass.
struct CSVTimestamp: Sendable, Equatable {
    let milliseconds: Int64

    init(_ date: Date) {
        milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// `2026-10-15T06:00:00.250Z` or `2026-10-15T06:00:00Z`; UTC only.
    init?(iso text: String) {
        guard let match = text.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?Z/),
              let fields = Self.fields(
                  year: match.1, month: match.2, day: match.3, hour: match.4, minute: match.5, second: match.6
              ),
              let seconds = Self.secondsSince1970(fields) else {
            return nil
        }
        let fraction = match.7.map { String($0).padding(toLength: 3, withPad: "0", startingAt: 0) } ?? "000"
        milliseconds = seconds * 1000 + (Int64(fraction) ?? 0)
    }

    var date: Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    var iso: String {
        formatted(dateTimeSeparator: "T", suffix: "Z")
    }

    /// The text GRDB stores for a `Date` (UTC, no zone suffix).
    var databaseText: String {
        formatted(dateTimeSeparator: " ", suffix: "")
    }

    private struct Fields: Equatable {
        let year, month, day, hour, minute, second: Int32
    }

    private func formatted(dateTimeSeparator: String, suffix: String) -> String {
        let (seconds, millis) = milliseconds.quotientAndRemainder(dividingBy: 1000)
        let wholeSeconds = millis < 0 ? seconds - 1 : seconds
        let fraction = millis < 0 ? millis + 1000 : millis
        let f = Self.fields(secondsSince1970: wholeSeconds)
        return String(
            format: "%04d-%02d-%02d%@%02d:%02d:%02d.%03d%@",
            f.year, f.month, f.day, dateTimeSeparator, f.hour, f.minute, f.second, Int32(fraction), suffix
        )
    }

    private static func fields(
        year: Substring, month: Substring, day: Substring, hour: Substring, minute: Substring, second: Substring
    ) -> Fields? {
        let values = [year, month, day, hour, minute, second].compactMap { Int32($0) }
        guard values.count == 6 else { return nil }
        return Fields(year: values[0], month: values[1], day: values[2], hour: values[3], minute: values[4], second: values[5])
    }

    /// `nil` for a date that does not exist (month 13, 31 April): `timegm`
    /// would roll it over, so the result must read back as the same fields.
    private static func secondsSince1970(_ fields: Fields) -> Int64? {
        var parts = tm()
        parts.tm_year = fields.year - 1900
        parts.tm_mon = fields.month - 1
        parts.tm_mday = fields.day
        parts.tm_hour = fields.hour
        parts.tm_min = fields.minute
        parts.tm_sec = fields.second
        let seconds = Int64(timegm(&parts))
        return Self.fields(secondsSince1970: seconds) == fields ? seconds : nil
    }

    private static func fields(secondsSince1970 seconds: Int64) -> Fields {
        var time = time_t(seconds)
        var parts = tm()
        gmtime_r(&time, &parts)
        return Fields(
            year: parts.tm_year + 1900, month: parts.tm_mon + 1, day: parts.tm_mday,
            hour: parts.tm_hour, minute: parts.tm_min, second: parts.tm_sec
        )
    }
}
