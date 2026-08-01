// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class ScheduleCalculatorTests: XCTestCase {
    var calendar: Calendar!
    // Monday 2024-01-01 10:00 UTC
    let now = Date(timeIntervalSince1970: 1_704_103_200)

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
    }

    func testManualReturnsNil() throws {
        let schedule = AutomationSchedule(frequency: .manual)
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: now, calendar: calendar)
        XCTAssertNil(next)
    }

    func testDailyBeforeConfiguredTime() throws {
        let schedule = AutomationSchedule(frequency: .daily, hour: 14, minute: 30)
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: now, calendar: calendar)
        XCTAssertNotNil(next)
        XCTAssertEqual(calendar.component(.hour, from: next!), 14)
        XCTAssertEqual(calendar.component(.minute, from: next!), 30)
        XCTAssertEqual(calendar.component(.day, from: next!), 1)
    }

    func testDailyAfterConfiguredTimeGoesTomorrow() throws {
        let schedule = AutomationSchedule(frequency: .daily, hour: 8, minute: 0)
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: now, calendar: calendar)
        XCTAssertNotNil(next)
        XCTAssertEqual(calendar.component(.day, from: next!), 2)
        XCTAssertEqual(calendar.component(.hour, from: next!), 8)
    }

    func testWeeklyChoosesEarliestCandidate() throws {
        // now is Monday (weekday 2 in US). Select Wed and Fri.
        let schedule = AutomationSchedule(
            frequency: .weekly,
            hour: 9,
            minute: 0,
            daysOfWeek: [4, 6] // Wed, Fri
        )
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: now, calendar: calendar)
        XCTAssertNotNil(next)
        XCTAssertEqual(calendar.component(.weekday, from: next!), 4)
    }

    func testEmptyWeekdaysInvalid() {
        let schedule = AutomationSchedule(frequency: .weekly, daysOfWeek: [])
        XCTAssertThrowsError(try ScheduleCalculator.validate(schedule))
    }

    func testMonthlyClampsShortMonths() throws {
        // Feb 2024 has 29 days; request day 31 → clamp to 29
        let comps = DateComponents(year: 2024, month: 1, day: 31, hour: 12)
        let after = calendar.date(from: comps)!
        let schedule = AutomationSchedule(frequency: .monthly, hour: 8, minute: 0, dayOfMonth: 31)
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: after, calendar: calendar)
        XCTAssertNotNil(next)
        XCTAssertEqual(calendar.component(.month, from: next!), 2)
        XCTAssertEqual(calendar.component(.day, from: next!), 29)
    }

    func testHourly() throws {
        let schedule = AutomationSchedule(frequency: .hourly)
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: now, calendar: calendar)
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next!, now)
        XCTAssertEqual(calendar.component(.minute, from: next!), 0)
    }

    func testRetryBackoffIncreases() {
        let t0 = ScheduleCalculator.retryDate(retryCount: 1, after: now)
        let t1 = ScheduleCalculator.retryDate(retryCount: 2, after: now)
        let t2 = ScheduleCalculator.retryDate(retryCount: 3, after: now)
        XCTAssertLessThan(t0, t1)
        XCTAssertLessThan(t1, t2)
    }

    func testCompletedRunAdvancesWithoutImmediateRerun() throws {
        let schedule = AutomationSchedule(frequency: .daily, hour: 10, minute: 0)
        // Exactly at scheduled time → next is tomorrow
        let comps = DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0)
        let atTime = calendar.date(from: comps)!
        let next = try ScheduleCalculator.nextEligibleDate(for: schedule, after: atTime, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: next!), 2)
    }
}
