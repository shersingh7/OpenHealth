import Foundation

/// Pure helpers for ensuring enabled scheduled automations always have a nextEligibleAt.
public enum ScheduleHydration {

    /// Returns a copy of automations with missing nextEligibleAt filled for enabled non-manual jobs.
    /// - Returns: `(hydrated, changedIDs)` where changedIDs lists automations that were updated.
    public static func hydrateMissingDates(
        _ automations: [Automation],
        now: Date,
        calendar: Calendar
    ) throws -> (automations: [Automation], changedIDs: [UUID]) {
        var result = automations
        var changed: [UUID] = []
        for index in result.indices {
            let item = result[index]
            guard item.isEnabled, item.schedule.frequency != .manual, item.nextEligibleAt == nil else {
                continue
            }
            let next = try ScheduleCalculator.nextEligibleDate(
                for: item.schedule,
                after: now,
                calendar: calendar
            )
            result[index].nextEligibleAt = next
            result[index].lastModified = now
            changed.append(item.id)
        }
        return (result, changed)
    }

    /// Earliest nextEligibleAt among enabled non-manual automations (after hydration).
    public static func earliestEligibleDate(in automations: [Automation]) -> Date? {
        automations
            .filter { $0.isEnabled && $0.schedule.frequency != .manual }
            .compactMap(\.nextEligibleAt)
            .min()
    }
}
