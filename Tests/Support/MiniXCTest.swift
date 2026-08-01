import Foundation

// Minimal XCTest-compatible harness for Command Line Tools environments
// without the full Xcode XCTest framework.

open class XCTestCase {
    public init() {}
    open func setUp() {}
    open func tearDown() {}
}

public struct XCTIssue: Error {
    public let message: String
    public let file: StaticString
    public let line: UInt
}

public func XCTAssertTrue(
    _ expression: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if !expression() {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertTrue failed" : message(), file: file, line: line)
    }
}

public func XCTAssertFalse(
    _ expression: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if expression() {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertFalse failed" : message(), file: file, line: line)
    }
}

public func XCTAssertEqual<T: Equatable>(
    _ expression1: @autoclosure () -> T,
    _ expression2: @autoclosure () -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let msg = message().isEmpty ? "XCTAssertEqual failed: \(a) != \(b)" : message()
        TestRuntime.recordFailure(msg, file: file, line: line)
    }
}

public func XCTAssertNotEqual<T: Equatable>(
    _ expression1: @autoclosure () -> T,
    _ expression2: @autoclosure () -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let a = expression1()
    let b = expression2()
    if a == b {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertNotEqual failed" : message(), file: file, line: line)
    }
}

public func XCTAssertNil(
    _ expression: @autoclosure () -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if expression() != nil {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertNil failed" : message(), file: file, line: line)
    }
}

public func XCTAssertNotNil(
    _ expression: @autoclosure () -> Any?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if expression() == nil {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertNotNil failed" : message(), file: file, line: line)
    }
}

public func XCTAssertGreaterThan<T: Comparable>(
    _ expression1: @autoclosure () -> T,
    _ expression2: @autoclosure () -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let a = expression1()
    let b = expression2()
    if !(a > b) {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertGreaterThan failed: \(a) !> \(b)" : message(), file: file, line: line)
    }
}

public func XCTAssertLessThan<T: Comparable>(
    _ expression1: @autoclosure () -> T,
    _ expression2: @autoclosure () -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let a = expression1()
    let b = expression2()
    if !(a < b) {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertLessThan failed: \(a) !< \(b)" : message(), file: file, line: line)
    }
}

public func XCTAssertLessThanOrEqual<T: Comparable>(
    _ expression1: @autoclosure () -> T,
    _ expression2: @autoclosure () -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let a = expression1()
    let b = expression2()
    if !(a <= b) {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertLessThanOrEqual failed" : message(), file: file, line: line)
    }
}

public func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) {
    do {
        _ = try expression()
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertThrowsError failed: no error thrown" : message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

public func XCTAssertNoThrow<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        _ = try expression()
    } catch {
        TestRuntime.recordFailure(message().isEmpty ? "XCTAssertNoThrow failed: \(error)" : message(), file: file, line: line)
    }
}

public func XCTFail(
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    TestRuntime.recordFailure(message.isEmpty ? "XCTFail" : message, file: file, line: line)
}

public enum TestRuntime {
    private static let lock = NSLock()
    private static var failures: [(String, String, UInt)] = []
    private static var currentTest = ""

    public static func beginTest(_ name: String) {
        lock.lock()
        currentTest = name
        lock.unlock()
    }

    public static func recordFailure(_ message: String, file: StaticString, line: UInt) {
        lock.lock()
        failures.append((currentTest, "\(file):\(line): \(message)", line))
        lock.unlock()
        fputs("FAIL \(file):\(line): \(message)\n", stderr)
    }

    public static func drainFailures() -> [(String, String, UInt)] {
        lock.lock()
        defer { lock.unlock() }
        let f = failures
        failures = []
        return f
    }

    public static func reset() {
        lock.lock()
        failures = []
        currentTest = ""
        lock.unlock()
    }
}

public struct RegisteredTest {
    public let suite: String
    public let name: String
    public let body: () async throws -> Void

    public init(suite: String, name: String, body: @escaping () async throws -> Void) {
        self.suite = suite
        self.name = name
        self.body = body
    }
}

public enum TestRegistry {
    nonisolated(unsafe) public static var tests: [RegisteredTest] = []

    public static func register(_ test: RegisteredTest) {
        tests.append(test)
    }
}

@main
enum TestMain {
    static func main() async {
        TestRegistry.bootstrap()
        var failed = 0
        var passed = 0
        let tests = TestRegistry.tests.sorted { $0.suite == $1.suite ? $0.name < $1.name : $0.suite < $1.suite }
        print("Running \(tests.count) tests…")
        for test in tests {
            TestRuntime.reset()
            TestRuntime.beginTest("\(test.suite).\(test.name)")
            do {
                try await test.body()
                let failures = TestRuntime.drainFailures()
                if failures.isEmpty {
                    passed += 1
                    print("✔ \(test.suite).\(test.name)")
                } else {
                    failed += 1
                    print("✘ \(test.suite).\(test.name) (\(failures.count) failure(s))")
                }
            } catch {
                failed += 1
                print("✘ \(test.suite).\(test.name) threw: \(error)")
            }
        }
        print("—")
        print("\(passed) passed, \(failed) failed, \(tests.count) total")
        if failed > 0 {
            exit(1)
        }
    }
}
