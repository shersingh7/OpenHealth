// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

/// Pure reconciliation logic: earliest next job → single background request.
final class AutomationCoordinatorLogicTests: XCTestCase {
    func testEarliestAmongEnabled() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_704_103_200)

        let daily = AutomationSchedule(frequency: .daily, hour: 15, minute: 0)
        let weekly = AutomationSchedule(frequency: .weekly, hour: 9, minute: 0, daysOfWeek: [3]) // Tuesday

        let d1 = try ScheduleCalculator.nextEligibleDate(for: daily, after: now, calendar: calendar)!
        let d2 = try ScheduleCalculator.nextEligibleDate(for: weekly, after: now, calendar: calendar)!
        let earliest = min(d1, d2)

        let scheduler = FakeBackgroundScheduler()
        try scheduler.submit(BackgroundTaskRequest(identifier: "com.shersingh7.openhealth.refresh", earliestBeginDate: earliest))
        XCTAssertEqual(scheduler.pendingCount, 1)
        XCTAssertEqual(scheduler.latest?.earliestBeginDate, earliest)

        // Reconcile: cancel + single submit
        scheduler.cancel(identifier: "com.shersingh7.openhealth.refresh")
        try scheduler.submit(BackgroundTaskRequest(identifier: "com.shersingh7.openhealth.refresh", earliestBeginDate: d1))
        XCTAssertEqual(scheduler.pendingCount, 1)
    }

    func testNoEnabledJobsCancels() throws {
        let scheduler = FakeBackgroundScheduler()
        try scheduler.submit(BackgroundTaskRequest(identifier: "com.shersingh7.openhealth.refresh", earliestBeginDate: Date()))
        scheduler.cancel(identifier: "com.shersingh7.openhealth.refresh")
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertEqual(scheduler.cancelled, ["com.shersingh7.openhealth.refresh"])
    }
}
