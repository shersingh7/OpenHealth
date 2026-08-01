// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class DateRangeResolverTests: XCTestCase {
    var calendar: Calendar!
    let now = Date(timeIntervalSince1970: 1_704_110_400) // 2024-01-01 12:00:00 UTC

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
    }

    func testTodayIsHalfOpenDay() throws {
        let interval = try DateRangeResolver.resolve(.today, now: now, calendar: calendar)
        XCTAssertEqual(interval.start, calendar.startOfDay(for: now))
        XCTAssertEqual(interval.end, calendar.date(byAdding: .day, value: 1, to: interval.start))
        XCTAssertTrue(interval.contains(now))
        // Half-open semantics: end is exclusive (start + 1 day == end; duration is 86400s in UTC).
        XCTAssertEqual(interval.duration, 24 * 60 * 60)
        let justBeforeEnd = interval.end.addingTimeInterval(-0.001)
        XCTAssertTrue(interval.contains(justBeforeEnd))
    }

    func testYesterday() throws {
        let interval = try DateRangeResolver.resolve(.yesterday, now: now, calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        XCTAssertEqual(interval.end, todayStart)
        XCTAssertEqual(interval.start, calendar.date(byAdding: .day, value: -1, to: todayStart))
    }

    func testLast24HoursRolling() throws {
        let interval = try DateRangeResolver.resolve(.last24Hours, now: now, calendar: calendar)
        XCTAssertEqual(interval.end, now)
        XCTAssertEqual(interval.start, now.addingTimeInterval(-24 * 3600))
    }

    func testThisWeek() throws {
        let interval = try DateRangeResolver.resolve(.thisWeek, now: now, calendar: calendar)
        XCTAssertLessThanOrEqual(interval.start, now)
        XCTAssertGreaterThan(interval.end, interval.start)
    }

    func testLastWeek() throws {
        let thisWeek = try DateRangeResolver.resolve(.thisWeek, now: now, calendar: calendar)
        let lastWeek = try DateRangeResolver.resolve(.lastWeek, now: now, calendar: calendar)
        XCTAssertEqual(lastWeek.end, thisWeek.start)
    }

    func testThisMonth() throws {
        let interval = try DateRangeResolver.resolve(.thisMonth, now: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: interval.start), 1)
        XCTAssertEqual(calendar.component(.month, from: interval.start), 1)
    }

    func testLastMonth() throws {
        let thisMonth = try DateRangeResolver.resolve(.thisMonth, now: now, calendar: calendar)
        let lastMonth = try DateRangeResolver.resolve(.lastMonth, now: now, calendar: calendar)
        XCTAssertEqual(lastMonth.end, thisMonth.start)
    }

    func testThisYearAndLastYear() throws {
        let thisYear = try DateRangeResolver.resolve(.thisYear, now: now, calendar: calendar)
        let lastYear = try DateRangeResolver.resolve(.lastYear, now: now, calendar: calendar)
        XCTAssertEqual(lastYear.end, thisYear.start)
        XCTAssertEqual(calendar.component(.year, from: thisYear.start), 2024)
    }

    func testAllTime() throws {
        let interval = try DateRangeResolver.resolve(.allTime, now: now, calendar: calendar)
        XCTAssertEqual(interval.start, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(interval.end, now)
    }

    func testCustomValid() throws {
        let start = now.addingTimeInterval(-3600)
        let end = now
        let interval = try DateRangeResolver.resolve(.custom(start: start, end: end), now: now, calendar: calendar)
        XCTAssertEqual(interval.start, start)
        XCTAssertEqual(interval.end, end)
    }

    func testCustomStartNotBeforeEnd() {
        XCTAssertThrowsError(
            try DateRangeResolver.resolve(.custom(start: now, end: now), now: now, calendar: calendar)
        )
    }

    func testCustomEndFarFutureRejected() {
        let end = now.addingTimeInterval(10_000)
        XCTAssertThrowsError(
            try DateRangeResolver.resolve(
                .custom(start: now.addingTimeInterval(-1), end: end),
                now: now,
                calendar: calendar
            )
        )
    }

    func testDSTSpringForwardUS() throws {
        var eastern = Calendar(identifier: .gregorian)
        eastern.timeZone = TimeZone(identifier: "America/New_York")!
        // 2024-03-10 12:00 Eastern (after spring forward)
        let comps = DateComponents(year: 2024, month: 3, day: 10, hour: 12)
        let noon = eastern.date(from: comps)!
        let interval = try DateRangeResolver.resolve(.today, now: noon, calendar: eastern)
        XCTAssertEqual(eastern.component(.day, from: interval.start), 10)
        XCTAssertEqual(eastern.component(.day, from: interval.end), 11)
    }

    func testDSTFallBackUS() throws {
        var eastern = Calendar(identifier: .gregorian)
        eastern.timeZone = TimeZone(identifier: "America/New_York")!
        let comps = DateComponents(year: 2024, month: 11, day: 3, hour: 12)
        let noon = eastern.date(from: comps)!
        let interval = try DateRangeResolver.resolve(.today, now: noon, calendar: eastern)
        XCTAssertLessThan(interval.start, interval.end)
    }
}
