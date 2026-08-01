import Foundation
import HealthKit

/// Live HealthKit adapter. Never reports definitive read authorization.
final class LiveHealthDataSource: HealthDataSource, @unchecked Sendable {
    private let healthStore: HKHealthStore
    private let settingsStore: any SettingsStore
    private let routeReader: WorkoutRouteReader
    private let calendar: Calendar
    private let queryConcurrencyLimit = 4

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        settingsStore: any SettingsStore,
        calendar: Calendar = Calendar.current
    ) {
        self.healthStore = healthStore
        self.settingsStore = settingsStore
        self.routeReader = WorkoutRouteReader(healthStore: healthStore)
        self.calendar = calendar
    }

    func supportedMetricIDs() -> Set<String> {
        HealthMetricCatalogCore.supportedQuantityIDs
            .union(HealthMetricCatalogCore.supportedCategoryIDs)
            .union([
                HealthMetricCatalogCore.workoutsID,
                HealthMetricCatalogCore.workoutRoutesID,
                HealthMetricCatalogCore.electrocardiogramsID,
                HealthMetricCatalogCore.activitySummariesID
            ])
    }

    func accessState() async -> HealthAccessState {
        let available = HKHealthStore.isHealthDataAvailable()
        guard available else {
            return HealthAccessState(isHealthDataAvailable: false, requestState: .unavailable)
        }

        let settings = await settingsStore.load()
        if let last = settings.healthAccessLastRequestedAt {
            return HealthAccessState(
                isHealthDataAvailable: true,
                requestState: .previouslyRequested,
                lastRequestedAt: last
            )
        }

        // Swift async import of HKHealthStore.requestStatusForAuthorization(toShare:read:).
        do {
            let types = HealthMetricCatalog.allSupportedObjectTypes
            let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
            switch status {
            case .shouldRequest:
                return HealthAccessState(isHealthDataAvailable: true, requestState: .requestRecommended)
            case .unnecessary:
                return HealthAccessState(
                    isHealthDataAvailable: true,
                    requestState: .previouslyRequested,
                    lastRequestedAt: settings.healthAccessLastRequestedAt
                )
            case .unknown:
                return HealthAccessState(isHealthDataAvailable: true, requestState: .notRequested)
            @unknown default:
                return HealthAccessState(isHealthDataAvailable: true, requestState: .notRequested)
            }
        } catch {
            AppLogger.health.error("Access status check failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            return HealthAccessState(isHealthDataAvailable: true, requestState: .notRequested)
        }
    }

    func requestReadAccess() async throws -> HealthAccessState {
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthAccessState(isHealthDataAvailable: false, requestState: .unavailable)
        }
        let types = HealthMetricCatalog.allSupportedObjectTypes
        try await healthStore.requestAuthorization(toShare: [], read: types)

        var settings = await settingsStore.load()
        settings.healthAccessLastRequestedAt = Date()
        settings.healthAccessRequestState = .previouslyRequested
        try await settingsStore.save(settings)

        return HealthAccessState(
            isHealthDataAvailable: true,
            requestState: .previouslyRequested,
            lastRequestedAt: settings.healthAccessLastRequestedAt
        )
    }

    func fetchSnapshot(options: HealthQueryOptions) async throws -> HealthDataSnapshot {
        var snapshot = HealthDataSnapshot()
        let interval = options.interval

        let quantityIDs = options.metricIDs.filter { HealthMetricCatalogCore.supportedQuantityIDs.contains($0) }
        let categoryIDs = options.metricIDs.filter { HealthMetricCatalogCore.supportedCategoryIDs.contains($0) }

        // Bounded concurrent quantity queries
        let quantityResults = try await mapLimited(Array(quantityIDs), limit: queryConcurrencyLimit) { metricID in
            let predicate = HKQuery.predicateForSamples(
                withStart: interval.start,
                end: interval.end,
                options: .strictStartDate
            )
            return try await self.fetchQuantity(metricID: metricID, predicate: predicate, includeMetadata: options.includeMetadata)
        }
        for result in quantityResults {
            snapshot.quantityRecords.append(contentsOf: result.records)
            snapshot.warnings.append(contentsOf: result.warnings)
        }

        try Task.checkCancellation()

        let categoryResults = try await mapLimited(Array(categoryIDs), limit: queryConcurrencyLimit) { metricID in
            let predicate = HKQuery.predicateForSamples(
                withStart: interval.start,
                end: interval.end,
                options: .strictStartDate
            )
            return try await self.fetchCategory(metricID: metricID, predicate: predicate, includeMetadata: options.includeMetadata)
        }
        for result in categoryResults {
            snapshot.categoryRecords.append(contentsOf: result.records)
            snapshot.warnings.append(contentsOf: result.warnings)
        }

        try Task.checkCancellation()

        // Never force workouts/routes solely from includeWorkoutRoutes — selection must include them.
        let wantWorkouts = MetricSelectionResolver.shouldQueryWorkouts(metricIDs: options.metricIDs)
        let wantRoutes = MetricSelectionResolver.shouldIncludeRoutes(
            metricIDs: options.metricIDs,
            includeWorkoutRoutes: options.includeWorkoutRoutes
        )
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        if wantWorkouts {
            do {
                let workouts = try await fetchWorkouts(predicate: predicate)
                for workout in workouts {
                    try Task.checkCancellation()
                    var routePoints: [RoutePointRecord]?
                    if wantRoutes {
                        do {
                            let points = try await routeReader.fetchRoutePoints(for: workout)
                            if points.isEmpty {
                                snapshot.warnings.append(ExportWarning(
                                    code: "no_route_data",
                                    message: "Workout has no route data",
                                    metricID: HealthMetricCatalogCore.workoutRoutesID
                                ))
                                routePoints = nil
                            } else {
                                routePoints = points
                            }
                        } catch {
                            snapshot.warnings.append(ExportWarning(
                                code: "route_query_failed",
                                message: "Route query failed for a workout",
                                metricID: HealthMetricCatalogCore.workoutRoutesID
                            ))
                        }
                    }
                    snapshot.workouts.append(
                        HealthKitRecordMapper.workoutRecord(
                            from: workout,
                            routePoints: routePoints,
                            includeMetadata: options.includeMetadata
                        )
                    )
                }
            } catch {
                snapshot.warnings.append(ExportWarning(
                    code: "workout_query_failed",
                    message: "Workout query failed",
                    metricID: HealthMetricCatalogCore.workoutsID
                ))
            }
        }

        try Task.checkCancellation()

        if options.metricIDs.contains(HealthMetricCatalogCore.electrocardiogramsID) {
            do {
                let ecgs = try await fetchECGs(
                    predicate: predicate,
                    includeWaveforms: options.includeECGWaveforms,
                    includeMetadata: options.includeMetadata
                )
                snapshot.electrocardiograms.append(contentsOf: ecgs.records)
                snapshot.warnings.append(contentsOf: ecgs.warnings)
            } catch {
                snapshot.warnings.append(ExportWarning(
                    code: "ecg_query_failed",
                    message: "ECG query failed",
                    metricID: HealthMetricCatalogCore.electrocardiogramsID
                ))
            }
        }

        try Task.checkCancellation()

        if options.metricIDs.contains(HealthMetricCatalogCore.activitySummariesID) {
            do {
                let summaries = try await fetchActivitySummaries(interval: interval)
                snapshot.activitySummaries.append(contentsOf: summaries)
            } catch {
                snapshot.warnings.append(ExportWarning(
                    code: "activity_summary_failed",
                    message: "Activity summary query failed",
                    metricID: HealthMetricCatalogCore.activitySummariesID
                ))
            }
        }

        return snapshot
    }

    func scanCoverage(interval: DateInterval) async throws -> DataCoverageSnapshot {
        var detected = Set<String>()

        let quantityIDs = Array(HealthMetricCatalogCore.supportedQuantityIDs)
        let results = try await mapLimited(quantityIDs, limit: queryConcurrencyLimit) { metricID -> String? in
            guard let type = HealthMetricCatalog.quantityType(for: metricID) else { return nil }
            let predicate = HKQuery.predicateForSamples(
                withStart: interval.start,
                end: interval.end,
                options: .strictStartDate
            )
            let count = try await self.countSamples(type: type, predicate: predicate)
            return count > 0 ? metricID : nil
        }
        detected.formUnion(results.compactMap { $0 })

        let categoryIDs = Array(HealthMetricCatalogCore.supportedCategoryIDs)
        let catResults = try await mapLimited(categoryIDs, limit: queryConcurrencyLimit) { metricID -> String? in
            guard let type = HealthMetricCatalog.categoryType(for: metricID) else { return nil }
            let predicate = HKQuery.predicateForSamples(
                withStart: interval.start,
                end: interval.end,
                options: .strictStartDate
            )
            let count = try await self.countSamples(type: type, predicate: predicate)
            return count > 0 ? metricID : nil
        }
        detected.formUnion(catResults.compactMap { $0 })

        // Special types presence (best effort)
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        if try await countSamples(type: HKObjectType.workoutType(), predicate: predicate) > 0 {
            detected.insert(HealthMetricCatalogCore.workoutsID)
        }

        return DataCoverageSnapshot(
            scannedAt: Date(),
            detectedMetricIDs: detected,
            supportedMetricCount: supportedMetricIDs().count
        )
    }

    // MARK: - Private queries

    private struct QuantityFetch {
        var records: [QuantityRecord]
        var warnings: [ExportWarning]
    }

    private struct CategoryFetch {
        var records: [CategoryRecord]
        var warnings: [ExportWarning]
    }

    private func fetchQuantity(metricID: String, predicate: NSPredicate, includeMetadata: Bool) async throws -> QuantityFetch {
        guard let type = HealthMetricCatalog.quantityType(for: metricID) else {
            return QuantityFetch(records: [], warnings: [
                ExportWarning(code: "unsupported_type", message: "Unsupported quantity type", metricID: metricID)
            ])
        }
        guard let unit = HealthMetricCatalog.unit(for: metricID) else {
            return QuantityFetch(records: [], warnings: [
                ExportWarning(code: "unsupported_unit", message: "No compatible unit for metric", metricID: metricID)
            ])
        }
        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                healthStore.execute(query)
            }
            let records = samples.map {
                HealthKitRecordMapper.quantityRecord(from: $0, metricID: metricID, unit: unit, includeMetadata: includeMetadata)
            }
            return QuantityFetch(records: records, warnings: [])
        } catch {
            return QuantityFetch(records: [], warnings: [
                ExportWarning(code: "query_failed", message: "Quantity query failed", metricID: metricID)
            ])
        }
    }

    private func fetchCategory(metricID: String, predicate: NSPredicate, includeMetadata: Bool) async throws -> CategoryFetch {
        guard let type = HealthMetricCatalog.categoryType(for: metricID) else {
            return CategoryFetch(records: [], warnings: [
                ExportWarning(code: "unsupported_type", message: "Unsupported category type", metricID: metricID)
            ])
        }
        do {
            let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
                healthStore.execute(query)
            }
            let records = samples.map {
                HealthKitRecordMapper.categoryRecord(from: $0, metricID: metricID, includeMetadata: includeMetadata)
            }
            return CategoryFetch(records: records, warnings: [])
        } catch {
            return CategoryFetch(records: [], warnings: [
                ExportWarning(code: "query_failed", message: "Category query failed", metricID: metricID)
            ])
        }
    }

    private func fetchWorkouts(predicate: NSPredicate) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private struct ECGFetch {
        var records: [ECGRecord]
        var warnings: [ExportWarning]
    }

    private func fetchECGs(predicate: NSPredicate, includeWaveforms: Bool, includeMetadata: Bool) async throws -> ECGFetch {
        let samples: [HKElectrocardiogram] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.electrocardiogramType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKElectrocardiogram]) ?? [])
            }
            healthStore.execute(query)
        }

        var records: [ECGRecord] = []
        var warnings: [ExportWarning] = []
        for ecg in samples {
            try Task.checkCancellation()
            var voltagePoints: [ECGVoltagePoint]?
            if includeWaveforms {
                do {
                    voltagePoints = try await fetchECGVoltage(ecg)
                } catch {
                    warnings.append(ExportWarning(
                        code: "ecg_waveform_failed",
                        message: "ECG metadata preserved; waveform unavailable",
                        metricID: HealthMetricCatalogCore.electrocardiogramsID
                    ))
                }
            }
            let avgHR = ecg.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            records.append(ECGRecord(
                id: ecg.uuid,
                startDate: ecg.startDate,
                endDate: ecg.endDate,
                classification: String(describing: ecg.classification),
                averageHeartRate: avgHR,
                samplingFrequency: ecg.samplingFrequency?.doubleValue(for: .hertz()),
                lead: nil,
                sourceName: ecg.sourceRevision.source.name,
                sourceBundleID: ecg.sourceRevision.source.bundleIdentifier,
                voltagePoints: voltagePoints,
                metadata: includeMetadata ? HealthKitRecordMapper.sanitizeMetadata(ecg.metadata) : nil
            ))
        }
        return ECGFetch(records: records, warnings: warnings)
    }

    private func fetchECGVoltage(_ ecg: HKElectrocardiogram) async throws -> [ECGVoltagePoint] {
        try await withCheckedThrowingContinuation { continuation in
            let accumulator = ECGWaveformAccumulator()
            let query = HKElectrocardiogramQuery(ecg) { _, result in
                switch result {
                case .error(let error):
                    if let completion = accumulator.finish(with: .failure(error)) {
                        continuation.resume(with: completion)
                    }
                case .measurement(let measurement):
                    if let value = measurement.quantity(for: .appleWatchSimilarToLeadI)?.doubleValue(for: .volt()) {
                        accumulator.append(ECGVoltagePoint(
                            timeSinceSampleStart: measurement.timeSinceSampleStart,
                            voltage: value
                        ))
                    }
                case .done:
                    if let completion = accumulator.finishSuccessfully() {
                        continuation.resume(with: completion)
                    }
                @unknown default:
                    break
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchActivitySummaries(interval: DateInterval) async throws -> [ActivitySummaryRecord] {
        var startComps = calendar.dateComponents([.year, .month, .day], from: interval.start)
        startComps.calendar = calendar
        var endComps = calendar.dateComponents([.year, .month, .day], from: interval.end.addingTimeInterval(-1))
        endComps.calendar = calendar

        let predicate = HKQuery.predicate(
            forActivitySummariesBetweenStart: startComps,
            end: endComps
        )

        let summaries: [HKActivitySummary] = try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: summaries ?? [])
            }
            healthStore.execute(query)
        }

        return summaries.compactMap { HealthKitRecordMapper.activitySummaryRecord(from: $0, calendar: calendar) }
    }

    private func countSamples(type: HKSampleType, predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    // Treat authorization/empty as zero without claiming denial
                    continuation.resume(returning: 0)
                    _ = error
                    return
                }
                continuation.resume(returning: samples?.isEmpty == false ? 1 : 0)
            }
            healthStore.execute(query)
        }
    }
}

/// HealthKit query callbacks are not documented as confined to one queue.
/// This state object prevents callback races and continuation double-resume.
private final class ECGWaveformAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var points: [ECGVoltagePoint] = []
    private var finished = false

    func append(_ point: ECGVoltagePoint) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        points.append(point)
    }

    func finishSuccessfully() -> Result<[ECGVoltagePoint], Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return nil }
        finished = true
        return .success(points)
    }

    func finish(with result: Result<[ECGVoltagePoint], Error>) -> Result<[ECGVoltagePoint], Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return nil }
        finished = true
        return result
    }
}

// MARK: - Bounded concurrency helper

private func mapLimited<T, R: Sendable>(
    _ items: [T],
    limit: Int,
    body: @escaping @Sendable (T) async throws -> R
) async throws -> [R] where T: Sendable {
    guard !items.isEmpty else { return [] }
    var results: [R?] = Array(repeating: nil, count: items.count)
    var nextIndex = 0
    let lock = NSLock()

    try await withThrowingTaskGroup(of: (Int, R).self) { group in
        func enqueue() {
            lock.lock()
            let index = nextIndex
            guard index < items.count else {
                lock.unlock()
                return
            }
            nextIndex += 1
            lock.unlock()
            let item = items[index]
            group.addTask {
                let value = try await body(item)
                return (index, value)
            }
        }

        for _ in 0..<min(limit, items.count) {
            enqueue()
        }

        for try await (index, value) in group {
            results[index] = value
            enqueue()
        }
    }
    return results.compactMap { $0 }
}
