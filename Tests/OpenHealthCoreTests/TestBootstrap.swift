import Foundation

// Registers all XCTest-style suites with the MiniXCTest runner.
// Each suite method is listed explicitly (no runtime ObjC discovery).

extension TestRegistry {
    static func bootstrap() {
        // Smoke
        register(suite: "SmokeTests", name: "testModuleImportsAndDateRangeResolves") {
            let t = SmokeTests(); t.setUp(); defer { t.tearDown() }
            try t.testModuleImportsAndDateRangeResolves()
        }
        register(suite: "SmokeTests", name: "testCatalogInvariants") {
            let t = SmokeTests(); t.setUp(); defer { t.tearDown() }
            t.testCatalogInvariants()
        }

        // Date ranges
        for (name, body) in dateRangeTests() {
            register(suite: "DateRangeResolverTests", name: name, body: body)
        }

        // Health metrics
        for (name, body) in healthMetricTests() {
            register(suite: "HealthMetricTests", name: name, body: body)
        }

        // Schema
        for (name, body) in exportSchemaTests() {
            register(suite: "ExportSchemaTests", name: name, body: body)
        }

        // Validators
        for (name, body) in validatorTests() {
            register(suite: "ValidatorTests", name: name, body: body)
        }

        // Schedule
        for (name, body) in scheduleTests() {
            register(suite: "ScheduleCalculatorTests", name: name, body: body)
        }

        // Encoders
        for (name, body) in encoderTests() {
            register(suite: "EncoderTests", name: name, body: body)
        }

        // Pipeline
        for (name, body) in pipelineTests() {
            register(suite: "ExportPipelineContractTests", name: name, body: body)
        }

        // Secrets
        for (name, body) in secretTests() {
            register(suite: "SecretStoreContractTests", name: name, body: body)
        }

        // Automation logic
        for (name, body) in automationLogicTests() {
            register(suite: "AutomationCoordinatorLogicTests", name: name, body: body)
        }

        // Corrective pass pure logic
        for (name, body) in correctivePassTests() {
            register(suite: "CorrectivePassTests", name: name, body: body)
        }
    }

    private static func register(suite: String, name: String, body: @escaping () async throws -> Void) {
        TestRegistry.register(RegisteredTest(suite: suite, name: name, body: body))
    }

    private static func dateRangeTests() -> [(String, () async throws -> Void)] {
        [
            ("testTodayIsHalfOpenDay", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testTodayIsHalfOpenDay() }),
            ("testYesterday", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testYesterday() }),
            ("testLast24HoursRolling", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testLast24HoursRolling() }),
            ("testThisWeek", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testThisWeek() }),
            ("testLastWeek", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testLastWeek() }),
            ("testThisMonth", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testThisMonth() }),
            ("testLastMonth", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testLastMonth() }),
            ("testThisYearAndLastYear", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testThisYearAndLastYear() }),
            ("testAllTime", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testAllTime() }),
            ("testCustomValid", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testCustomValid() }),
            ("testCustomStartNotBeforeEnd", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; t.testCustomStartNotBeforeEnd() }),
            ("testCustomEndFarFutureRejected", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; t.testCustomEndFarFutureRejected() }),
            ("testDSTSpringForwardUS", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testDSTSpringForwardUS() }),
            ("testDSTFallBackUS", { let t = DateRangeResolverTests(); t.setUp(); defer { t.tearDown() }; try t.testDSTFallBackUS() })
        ]
    }

    private static func healthMetricTests() -> [(String, () async throws -> Void)] {
        [
            ("testUniqueIDs", { HealthMetricTests().testUniqueIDs() }),
            ("testPercentMetricIndexUsesCanonicalPercentUnits", { HealthMetricTests().testPercentMetricIndexUsesCanonicalPercentUnits() }),
            ("testQuantityUnitsPresentCategoryUnitsAbsent", { HealthMetricTests().testQuantityUnitsPresentCategoryUnitsAbsent() }),
            ("testStepCountUsesFullRawIDAndCountUnit", { HealthMetricTests().testStepCountUsesFullRawIDAndCountUnit() }),
            ("testHeartRateNotCountFallback", { HealthMetricTests().testHeartRateNotCountFallback() }),
            ("testBodyMassUsesKilograms", { HealthMetricTests().testBodyMassUsesKilograms() }),
            ("testDisplayOrderingByCategory", { HealthMetricTests().testDisplayOrderingByCategory() }),
            ("testNormalizeIdentifierTrims", { HealthMetricTests().testNormalizeIdentifierTrims() }),
            ("testShortNameStripsPrefix", { HealthMetricTests().testShortNameStripsPrefix() }),
            ("testNoCountUnitForDistance", { HealthMetricTests().testNoCountUnitForDistance() })
        ]
    }

    private static func exportSchemaTests() -> [(String, () async throws -> Void)] {
        [
            ("testTotalRecordsDerivedFromSections", { ExportSchemaTests().testTotalRecordsDerivedFromSections() }),
            ("testJSONRoundTrip", { try ExportSchemaTests().testJSONRoundTrip() }),
            ("testEmptyDocumentCountsZero", { ExportSchemaTests().testEmptyDocumentCountsZero() })
        ]
    }

    private static func validatorTests() -> [(String, () async throws -> Void)] {
        [
            ("testValidNestedFolder", { try ValidatorTests().testValidNestedFolder() }),
            ("testRejectAbsolute", { ValidatorTests().testRejectAbsolute() }),
            ("testRejectParentTraversal", { ValidatorTests().testRejectParentTraversal() }),
            ("testCollapseRepeatedSeparators", { try ValidatorTests().testCollapseRepeatedSeparators() }),
            ("testRejectControlCharacters", { ValidatorTests().testRejectControlCharacters() }),
            ("testEmptyRejected", { ValidatorTests().testEmptyRejected() }),
            ("testHTTPSAccepted", { try ValidatorTests().testHTTPSAccepted() }),
            ("testHTTPLoopbackRequiresFlag", { ValidatorTests().testHTTPLoopbackRequiresFlag() }),
            ("testRejectFTP", { ValidatorTests().testRejectFTP() }),
            ("testRejectMissingHost", { ValidatorTests().testRejectMissingHost() }),
            ("testReservedHeadersRejected", { ValidatorTests().testReservedHeadersRejected() }),
            ("testCSVEscaping", { ValidatorTests().testCSVEscaping() }),
            ("testXMLEscaping", { ValidatorTests().testXMLEscaping() }),
            ("testXMLFiltersInvalidScalars", { ValidatorTests().testXMLFiltersInvalidScalars() })
        ]
    }

    private static func scheduleTests() -> [(String, () async throws -> Void)] {
        [
            ("testManualReturnsNil", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testManualReturnsNil() }),
            ("testDailyBeforeConfiguredTime", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testDailyBeforeConfiguredTime() }),
            ("testDailyAfterConfiguredTimeGoesTomorrow", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testDailyAfterConfiguredTimeGoesTomorrow() }),
            ("testWeeklyChoosesEarliestCandidate", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testWeeklyChoosesEarliestCandidate() }),
            ("testEmptyWeekdaysInvalid", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; t.testEmptyWeekdaysInvalid() }),
            ("testMonthlyClampsShortMonths", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testMonthlyClampsShortMonths() }),
            ("testHourly", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testHourly() }),
            ("testRetryBackoffIncreases", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; t.testRetryBackoffIncreases() }),
            ("testCompletedRunAdvancesWithoutImmediateRerun", { let t = ScheduleCalculatorTests(); t.setUp(); defer { t.tearDown() }; try t.testCompletedRunAdvancesWithoutImmediateRerun() })
        ]
    }

    private static func encoderTests() -> [(String, () async throws -> Void)] {
        [
            ("testCSVContainsSectionsAndEscaping", { try EncoderTests().testCSVContainsSectionsAndEscaping() }),
            ("testGPXFailsWithoutRoutes", { EncoderTests().testGPXFailsWithoutRoutes() }),
            ("testGPXEscapesAndIsParseable", { try EncoderTests().testGPXEscapesAndIsParseable() }),
            ("testFilenameGeneratorUTC", { EncoderTests().testFilenameGeneratorUTC() })
        ]
    }

    private static func pipelineTests() -> [(String, () async throws -> Void)] {
        [
            ("testFullSuccess", { try await ExportPipelineContractTests().testFullSuccess() }),
            ("testPartialSuccess", { try await ExportPipelineContractTests().testPartialSuccess() }),
            ("testValidationFailureNoFetch", { try await ExportPipelineContractTests().testValidationFailureNoFetch() }),
            ("testGPXWithoutRoutesFailsEncoding", { try await ExportPipelineContractTests().testGPXWithoutRoutesFailsEncoding() })
        ]
    }

    private static func secretTests() -> [(String, () async throws -> Void)] {
        [
            ("testSaveLoadDelete", { try await SecretStoreContractTests().testSaveLoadDelete() }),
            ("testDestinationConfigDoesNotEmbedSecretMaterial", { try SecretStoreContractTests().testDestinationConfigDoesNotEmbedSecretMaterial() }),
            ("testStagedWriteIsInvisibleToUnderlyingUntilCommit", { try await SecretStoreContractTests().testStagedWriteIsInvisibleToUnderlyingUntilCommit() }),
            ("testStagedOverwriteDoesNotCorruptExistingUntilCommit", { try await SecretStoreContractTests().testStagedOverwriteDoesNotCorruptExistingUntilCommit() }),
            ("testStagedCommitAppliesWritesAndDeletes", { try await SecretStoreContractTests().testStagedCommitAppliesWritesAndDeletes() }),
            ("testStagedDeleteHidesExistingWithoutRemovingUntilCommit", { try await SecretStoreContractTests().testStagedDeleteHidesExistingWithoutRemovingUntilCommit() }),
            ("testCommitReceiptRollbackRestoresUnderlyingAndRestagesEdits", { try await SecretStoreContractTests().testCommitReceiptRollbackRestoresUnderlyingAndRestagesEdits() }),
            ("testCommitFailureCompensatesPartialWritesAndKeepsStaging", { try await SecretStoreContractTests().testCommitFailureCompensatesPartialWritesAndKeepsStaging() })
        ]
    }

    private static func automationLogicTests() -> [(String, () async throws -> Void)] {
        [
            ("testEarliestAmongEnabled", { try AutomationCoordinatorLogicTests().testEarliestAmongEnabled() }),
            ("testNoEnabledJobsCancels", { try AutomationCoordinatorLogicTests().testNoEnabledJobsCancels() })
        ]
    }

    private static func correctivePassTests() -> [(String, () async throws -> Void)] {
        [
            ("testAllDetectedMeansAllSupportedCatalog", { CorrectivePassTests().testAllDetectedMeansAllSupportedCatalog() }),
            ("testAllDetectedAddsRoutesOnlyWhenToggleOn", { CorrectivePassTests().testAllDetectedAddsRoutesOnlyWhenToggleOn() }),
            ("testExplicitDoesNotForceWorkoutsFromRouteToggle", { CorrectivePassTests().testExplicitDoesNotForceWorkoutsFromRouteToggle() }),
            ("testRoutesRequireWorkoutOrRouteSelection", { CorrectivePassTests().testRoutesRequireWorkoutOrRouteSelection() }),
            ("testExplicitSelectionIsNotExpanded", { CorrectivePassTests().testExplicitSelectionIsNotExpanded() }),
            ("testGPXValidationRequiresRoutes", { CorrectivePassTests().testGPXValidationRequiresRoutes() }),
            ("testDefaultRouteExportIsOff", { CorrectivePassTests().testDefaultRouteExportIsOff() }),
            ("testRejectHTTPRedirect", { CorrectivePassTests().testRejectHTTPRedirect() }),
            ("testAllowSameHostHTTPSRedirectWithoutCredentials", { CorrectivePassTests().testAllowSameHostHTTPSRedirectWithoutCredentials() }),
            ("testRejectCrossHostRedirectWhenCredentialsAttached", { CorrectivePassTests().testRejectCrossHostRedirectWhenCredentialsAttached() }),
            ("testRejectCrossPortRedirectWhenCredentialsAttached", { CorrectivePassTests().testRejectCrossPortRedirectWhenCredentialsAttached() }),
            ("testSameOriginIgnoresDefaultHTTPSPort", { CorrectivePassTests().testSameOriginIgnoresDefaultHTTPSPort() }),
            ("testRequestCarriesCredentialsDetectsAuthorization", { CorrectivePassTests().testRequestCarriesCredentialsDetectsAuthorization() }),
            ("testCredentialMarkerProtectsArbitraryAPIKeyHeaderNames", { CorrectivePassTests().testCredentialMarkerProtectsArbitraryAPIKeyHeaderNames() }),
            ("testSensitiveHeaderDetection", { CorrectivePassTests().testSensitiveHeaderDetection() }),
            ("testPartitionMovesSensitiveHeaders", { CorrectivePassTests().testPartitionMovesSensitiveHeaders() }),
            ("testAPIKeyHeaderNameValidation", { CorrectivePassTests().testAPIKeyHeaderNameValidation() }),
            ("testHydrateMissingNextEligibleAt", { try CorrectivePassTests().testHydrateMissingNextEligibleAt() }),
            ("testEarliestEligibleDate", { CorrectivePassTests().testEarliestEligibleDate() }),
            ("testAppSettingsPersistsCoverageIDs", { try CorrectivePassTests().testAppSettingsPersistsCoverageIDs() }),
            ("testAppSettingsMissingCoverageIDsDecodesEmpty", { try CorrectivePassTests().testAppSettingsMissingCoverageIDsDecodesEmpty() })
        ]
    }
}
