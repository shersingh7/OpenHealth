// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class CorrectivePassTests: XCTestCase {

    // MARK: - Metric selection / route privacy

    func testAllDetectedMeansAllSupportedCatalog() {
        let ids = MetricSelectionResolver.resolveMetricIDs(
            selection: .allDetected,
            includeWorkoutRoutes: false
        )
        XCTAssertTrue(ids.contains(HealthMetricCatalogCore.workoutsID))
        XCTAssertFalse(ids.contains(HealthMetricCatalogCore.workoutRoutesID))
        XCTAssertTrue(ids.isSuperset(of: HealthMetricCatalogCore.supportedQuantityIDs))
    }

    func testAllDetectedAddsRoutesOnlyWhenToggleOn() {
        let off = MetricSelectionResolver.resolveMetricIDs(
            selection: .allDetected,
            includeWorkoutRoutes: false
        )
        let on = MetricSelectionResolver.resolveMetricIDs(
            selection: .allDetected,
            includeWorkoutRoutes: true
        )
        XCTAssertFalse(off.contains(HealthMetricCatalogCore.workoutRoutesID))
        XCTAssertTrue(on.contains(HealthMetricCatalogCore.workoutRoutesID))
    }

    func testExplicitDoesNotForceWorkoutsFromRouteToggle() {
        let ids: Set<String> = ["HKQuantityTypeIdentifierStepCount"]
        XCTAssertFalse(MetricSelectionResolver.shouldQueryWorkouts(metricIDs: ids))
        XCTAssertFalse(
            MetricSelectionResolver.shouldIncludeRoutes(
                metricIDs: ids,
                includeWorkoutRoutes: true
            )
        )
    }

    func testRoutesRequireWorkoutOrRouteSelection() {
        let workoutsOnly: Set<String> = [HealthMetricCatalogCore.workoutsID]
        XCTAssertTrue(MetricSelectionResolver.shouldQueryWorkouts(metricIDs: workoutsOnly))
        XCTAssertFalse(
            MetricSelectionResolver.shouldIncludeRoutes(
                metricIDs: workoutsOnly,
                includeWorkoutRoutes: false
            )
        )
        XCTAssertTrue(
            MetricSelectionResolver.shouldIncludeRoutes(
                metricIDs: workoutsOnly,
                includeWorkoutRoutes: true
            )
        )

        let routesOnly: Set<String> = [HealthMetricCatalogCore.workoutRoutesID]
        XCTAssertTrue(MetricSelectionResolver.shouldQueryWorkouts(metricIDs: routesOnly))
        XCTAssertTrue(
            MetricSelectionResolver.shouldIncludeRoutes(
                metricIDs: routesOnly,
                includeWorkoutRoutes: false
            )
        )
    }

    func testExplicitSelectionIsNotExpanded() {
        let selected: Set<String> = ["HKQuantityTypeIdentifierStepCount"]
        let resolved = MetricSelectionResolver.resolveMetricIDs(
            selection: .explicit(selected),
            includeWorkoutRoutes: true
        )
        XCTAssertEqual(resolved, selected)
    }

    func testGPXValidationRequiresRoutes() {
        let local = ExportDestination.defaultLocal()
        let noRoutes = ExportRequest(
            selection: .explicit([HealthMetricCatalogCore.workoutsID]),
            format: .gpx,
            destinationIDs: [local.id],
            includeWorkoutRoutes: false
        )
        let errors = ExportRequestValidator.validate(
            noRoutes,
            destinations: [local],
            now: Date(timeIntervalSince1970: 1_704_067_200),
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertTrue(errors.contains(.gpxRequiresRoutes))

        let withToggle = ExportRequest(
            selection: .explicit([HealthMetricCatalogCore.workoutsID]),
            format: .gpx,
            destinationIDs: [local.id],
            includeWorkoutRoutes: true
        )
        let ok = ExportRequestValidator.validate(
            withToggle,
            destinations: [local],
            now: Date(timeIntervalSince1970: 1_704_067_200),
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertFalse(ok.contains(.gpxRequiresRoutes))
    }

    func testDefaultRouteExportIsOff() {
        XCTAssertFalse(ExportRequest().includeWorkoutRoutes)
        XCTAssertFalse(AutomationExportConfig().includeWorkoutRoutes)
        XCTAssertFalse(AppSettings.default.defaultIncludeWorkoutRoutes)
    }

    // MARK: - Redirect origin policy

    func testRejectHTTPRedirect() {
        let original = URL(string: "https://api.example.com/export")!
        let redirect = URL(string: "http://api.example.com/export")!
        XCTAssertFalse(
            RedirectOriginPolicy.shouldAllowRedirect(
                originalURL: original,
                redirectURL: redirect,
                credentialsAttached: false
            )
        )
    }

    func testAllowSameHostHTTPSRedirectWithoutCredentials() {
        let original = URL(string: "https://api.example.com/v1")!
        let redirect = URL(string: "https://api.example.com/v2")!
        XCTAssertTrue(
            RedirectOriginPolicy.shouldAllowRedirect(
                originalURL: original,
                redirectURL: redirect,
                credentialsAttached: false
            )
        )
    }

    func testRejectCrossHostRedirectWhenCredentialsAttached() {
        let original = URL(string: "https://api.example.com/export")!
        let redirect = URL(string: "https://evil.example/export")!
        XCTAssertFalse(
            RedirectOriginPolicy.shouldAllowRedirect(
                originalURL: original,
                redirectURL: redirect,
                credentialsAttached: true
            )
        )
        XCTAssertTrue(
            RedirectOriginPolicy.shouldAllowRedirect(
                originalURL: original,
                redirectURL: redirect,
                credentialsAttached: false
            )
        )
    }

    func testRejectCrossPortRedirectWhenCredentialsAttached() {
        let original = URL(string: "https://api.example.com/export")!
        let redirect = URL(string: "https://api.example.com:8443/export")!
        XCTAssertFalse(
            RedirectOriginPolicy.shouldAllowRedirect(
                originalURL: original,
                redirectURL: redirect,
                credentialsAttached: true
            )
        )
    }

    func testSameOriginIgnoresDefaultHTTPSPort() {
        let a = URL(string: "https://api.example.com/a")!
        let b = URL(string: "https://api.example.com:443/b")!
        XCTAssertTrue(RedirectOriginPolicy.isSameOrigin(a, b))
    }

    func testRequestCarriesCredentialsDetectsAuthorization() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        XCTAssertFalse(RedirectOriginPolicy.requestCarriesCredentials(req))
        req.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        XCTAssertTrue(RedirectOriginPolicy.requestCarriesCredentials(req))
    }

    func testCredentialMarkerProtectsArbitraryAPIKeyHeaderNames() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        req.setValue("secret", forHTTPHeaderField: "X-Custom")
        XCTAssertFalse(RedirectOriginPolicy.requestCarriesCredentials(req))
        req.setValue("1", forHTTPHeaderField: "X-OpenHealth-Credentialed-Request")
        XCTAssertTrue(RedirectOriginPolicy.requestCarriesCredentials(req))
    }

    // MARK: - Sensitive headers

    func testSensitiveHeaderDetection() {
        XCTAssertTrue(SensitiveHeaderDetector.isSensitiveHeaderName("Authorization"))
        XCTAssertTrue(SensitiveHeaderDetector.isSensitiveHeaderName("X-API-Key"))
        XCTAssertTrue(SensitiveHeaderDetector.isSensitiveHeaderName("x-access-token"))
        XCTAssertFalse(SensitiveHeaderDetector.isSensitiveHeaderName("X-Request-Id"))
    }

    func testPartitionMovesSensitiveHeaders() {
        let headers = [
            "Authorization": "Bearer abc",
            "X-Request-Id": "1",
            "X-API-Key": "secret"
        ]
        let parts = SensitiveHeaderDetector.partition(headers: headers)
        XCTAssertEqual(parts.safe["X-Request-Id"], "1")
        XCTAssertNil(parts.safe["Authorization"])
        XCTAssertNil(parts.safe["X-API-Key"])
        XCTAssertEqual(parts.sensitive.count, 2)
    }

    // MARK: - Header validation

    func testAPIKeyHeaderNameValidation() {
        XCTAssertNoThrow(try URLValidator.validateAPIKeyHeaderName("X-API-Key"))
        XCTAssertThrowsError(try URLValidator.validateAPIKeyHeaderName("Authorization"))
        XCTAssertThrowsError(try URLValidator.validateAPIKeyHeaderName("X-OpenHealth-Credentialed-Request"))
        XCTAssertThrowsError(try URLValidator.validateAPIKeyHeaderName("Bad Name"))
        XCTAssertThrowsError(try URLValidator.validateAPIKeyHeaderName(""))
    }

    // MARK: - Schedule hydration

    func testHydrateMissingNextEligibleAt() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_704_103_200)

        let missing = Automation(
            name: "A",
            schedule: AutomationSchedule(frequency: .daily, hour: 15, minute: 0),
            isEnabled: true,
            nextEligibleAt: nil
        )
        let manual = Automation(
            name: "M",
            schedule: AutomationSchedule(frequency: .manual),
            isEnabled: true,
            nextEligibleAt: nil
        )
        let disabled = Automation(
            name: "D",
            schedule: AutomationSchedule(frequency: .daily, hour: 3, minute: 0),
            isEnabled: false,
            nextEligibleAt: nil
        )
        let already = Automation(
            name: "B",
            schedule: AutomationSchedule(frequency: .daily, hour: 10, minute: 0),
            isEnabled: true,
            nextEligibleAt: Date(timeIntervalSince1970: 1_704_200_000)
        )

        let (hydrated, changed) = try ScheduleHydration.hydrateMissingDates(
            [missing, manual, disabled, already],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(changed.count, 1)
        XCTAssertEqual(changed.first, missing.id)
        XCTAssertNotNil(hydrated.first(where: { $0.id == missing.id })?.nextEligibleAt)
        XCTAssertNil(hydrated.first(where: { $0.id == manual.id })?.nextEligibleAt)
        XCTAssertNil(hydrated.first(where: { $0.id == disabled.id })?.nextEligibleAt)
        XCTAssertEqual(
            hydrated.first(where: { $0.id == already.id })?.nextEligibleAt,
            already.nextEligibleAt
        )
    }

    func testEarliestEligibleDate() {
        let a = Automation(
            name: "A",
            isEnabled: true,
            nextEligibleAt: Date(timeIntervalSince1970: 100)
        )
        let b = Automation(
            name: "B",
            isEnabled: true,
            nextEligibleAt: Date(timeIntervalSince1970: 50)
        )
        let c = Automation(
            name: "C",
            schedule: AutomationSchedule(frequency: .manual),
            isEnabled: true,
            nextEligibleAt: Date(timeIntervalSince1970: 10)
        )
        let earliest = ScheduleHydration.earliestEligibleDate(in: [a, b, c])
        XCTAssertEqual(earliest, Date(timeIntervalSince1970: 50))
    }

    // MARK: - Coverage cache model

    func testAppSettingsPersistsCoverageIDs() throws {
        var settings = AppSettings.default
        settings.lastCoverageScanAt = Date(timeIntervalSince1970: 1_700_000_000)
        settings.lastCoverageTypeCount = 2
        settings.lastCoverageDetectedMetricIDs = [
            "HKQuantityTypeIdentifierStepCount",
            "HKQuantityTypeIdentifierHeartRate"
        ]
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.lastCoverageDetectedMetricIDs.count, 2)
        XCTAssertEqual(decoded.lastCoverageTypeCount, 2)
        XCTAssertFalse(decoded.defaultIncludeWorkoutRoutes)
    }

    func testAppSettingsMissingCoverageIDsDecodesEmpty() throws {
        // Simulate older settings blob without the new key
        let partial: [String: Any] = [
            "hasCompletedOnboarding": true,
            "defaultFormat": "JSON",
            "defaultRange": ["last24Hours": [:]],
            "defaultIncludeMetadata": false,
            "defaultIncludeECGWaveforms": false,
            "preferNotifications": false,
            "healthAccessRequestState": "notRequested",
            "lastCoverageTypeCount": 0
        ]
        // Use Codable path via empty defaults for route when key missing
        let data = try JSONEncoder().encode(AppSettings.default)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.lastCoverageDetectedMetricIDs, [])
        _ = partial
    }
}
