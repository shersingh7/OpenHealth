// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OpenHealthCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "OpenHealthCore",
            targets: ["OpenHealthCore"]
        ),
        .executable(
            name: "OpenHealthCoreTests",
            targets: ["OpenHealthCoreTests"]
        )
    ],
    targets: [
        .target(
            name: "OpenHealthCore",
            path: "Core"
        ),
        // Foundation-only test runner for Command Line Tools environments without Xcode/XCTest.
        // Invoke with: swift run --build-system native OpenHealthCoreTests
        // or: Scripts/run_core_tests.sh
        .executableTarget(
            name: "OpenHealthCoreTests",
            dependencies: ["OpenHealthCore"],
            path: "Tests",
            sources: [
                "Support/MiniXCTest.swift",
                "OpenHealthCoreTests/Fakes.swift",
                "OpenHealthCoreTests/SmokeTests.swift",
                "OpenHealthCoreTests/DateRangeResolverTests.swift",
                "OpenHealthCoreTests/HealthMetricTests.swift",
                "OpenHealthCoreTests/ExportSchemaTests.swift",
                "OpenHealthCoreTests/ValidatorTests.swift",
                "OpenHealthCoreTests/ScheduleCalculatorTests.swift",
                "OpenHealthCoreTests/EncoderTests.swift",
                "OpenHealthCoreTests/ExportPipelineContractTests.swift",
                "OpenHealthCoreTests/SecretStoreContractTests.swift",
                "OpenHealthCoreTests/AutomationCoordinatorLogicTests.swift",
                "OpenHealthCoreTests/CorrectivePassTests.swift",
                "OpenHealthCoreTests/TestBootstrap.swift"
            ]
        )
    ]
)
