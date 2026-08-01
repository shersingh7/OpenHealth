import Foundation

/// Injectable clock for deterministic scheduling and date-range resolution.
public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}

public struct FixedClock: Clock {
    private let fixedDate: Date

    public init(_ date: Date) {
        self.fixedDate = date
    }

    public func now() -> Date { fixedDate }
}
