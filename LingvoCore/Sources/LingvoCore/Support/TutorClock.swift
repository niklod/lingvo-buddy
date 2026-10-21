import Foundation

/// The source of "now" for every time-based rule, so tests can move time by hand.
public protocol TutorClock: Sendable {
    func now() -> Date
}

public struct SystemClock: TutorClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}
