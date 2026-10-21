import Foundation
import LingvoCore

extension Fixture {
    /// A fixed zone, so local-time rules (quiet hours, "until tomorrow") do not
    /// depend on the machine that runs the tests.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return calendar
    }()

    /// Local time on 2026-10-15 in `calendar`, shifted by `dayOffset` days.
    static func date(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
        let components = DateComponents(year: 2026, month: 10, day: 15 + dayOffset, hour: hour, minute: minute)
        guard let date = calendar.date(from: components) else {
            preconditionFailure("invalid fixture date \(components)")
        }
        return date
    }

    /// The context a timer tick builds: default quiet hours, all other signals off.
    static func timedContext(
        quietHours: QuietHours? = .standard,
        isFocusOn: Bool = false,
        isFullScreenAppFrontmost: Bool = false,
        pausedUntil: Date? = nil
    ) -> CardContext {
        CardContext(
            trigger: .timer,
            quietHours: quietHours,
            isFocusOn: isFocusOn,
            isFullScreenAppFrontmost: isFullScreenAppFrontmost,
            pausedUntil: pausedUntil,
            calendar: calendar
        )
    }
}
