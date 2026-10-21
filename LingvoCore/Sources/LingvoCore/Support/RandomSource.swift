import Foundation
import Synchronization

/// The source of every random choice (option order, later the direction mix),
/// injected so tests and snapshots are reproducible.
public protocol RandomSource: Sendable {
    /// Returns a value in `0..<upperBound`. `upperBound` must be greater than zero.
    func nextInt(below upperBound: Int) -> Int
}

extension RandomSource {
    func shuffled<Element>(_ elements: [Element]) -> [Element] {
        var result = elements
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            result.swapAt(index, nextInt(below: index + 1))
        }
        return result
    }
}

public struct SystemRandomSource: RandomSource {
    public init() {}

    public func nextInt(below upperBound: Int) -> Int {
        Int.random(in: 0..<upperBound)
    }
}

/// SplitMix64: tiny, fast, and the same sequence on every platform for a given seed.
public final class SeededRandomSource: RandomSource {
    private let state: Mutex<UInt64>

    public init(seed: UInt64) {
        state = Mutex(seed)
    }

    public func nextInt(below upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let value = state.withLock { current -> UInt64 in
            current &+= 0x9E37_79B9_7F4A_7C15
            var mixed = current
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
        return Int(value % UInt64(upperBound))
    }
}
