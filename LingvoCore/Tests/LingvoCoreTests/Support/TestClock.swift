import Foundation
import LingvoCore
import Synchronization

final class TestClock: TutorClock {
    private let current: Mutex<Date>

    init(_ start: Date) {
        current = Mutex(start)
    }

    func now() -> Date {
        current.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}
