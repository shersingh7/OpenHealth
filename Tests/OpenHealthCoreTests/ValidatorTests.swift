// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class ValidatorTests: XCTestCase {
    // MARK: Path

    func testValidNestedFolder() throws {
        let path = try PathValidator.validateRelativeFolder("Exports/Health/2024")
        XCTAssertEqual(path, "Exports/Health/2024")
    }

    func testRejectAbsolute() {
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder("/absolute"))
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder("~/Documents"))
    }

    func testRejectParentTraversal() {
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder("../escape"))
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder("a/../../b"))
    }

    func testCollapseRepeatedSeparators() throws {
        let path = try PathValidator.validateRelativeFolder("a//b///c")
        XCTAssertEqual(path, "a/b/c")
    }

    func testRejectControlCharacters() {
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder("a/\u{0007}/b"))
    }

    func testEmptyRejected() {
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder(""))
        XCTAssertThrowsError(try PathValidator.validateRelativeFolder("   "))
    }

    // MARK: URL

    func testHTTPSAccepted() throws {
        let url = try URLValidator.validateHTTPSEndpoint("https://example.com/export")
        XCTAssertEqual(url.host, "example.com")
    }

    func testHTTPLoopbackRequiresFlag() {
        XCTAssertThrowsError(try URLValidator.validateHTTPSEndpoint("http://127.0.0.1:8080/x"))
        XCTAssertNoThrow(try URLValidator.validateHTTPSEndpoint("http://127.0.0.1:8080/x", allowLoopbackHTTP: true))
        XCTAssertNoThrow(try URLValidator.validateHTTPSEndpoint("http://localhost/x", allowLoopbackHTTP: true))
    }

    func testRejectFTP() {
        XCTAssertThrowsError(try URLValidator.validateHTTPSEndpoint("ftp://example.com/file"))
    }

    func testRejectMissingHost() {
        XCTAssertThrowsError(try URLValidator.validateHTTPSEndpoint("https://"))
    }

    func testReservedHeadersRejected() {
        XCTAssertThrowsError(try URLValidator.validateCustomHeaders(["Authorization": "x"]))
        XCTAssertThrowsError(try URLValidator.validateCustomHeaders(["Host": "evil"]))
        XCTAssertNoThrow(try URLValidator.validateCustomHeaders(["X-Custom": "1"]))
    }

    // MARK: CSV / XML

    func testCSVEscaping() {
        XCTAssertEqual(CSVSanitizer.escapeField("plain"), "plain")
        XCTAssertEqual(CSVSanitizer.escapeField("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVSanitizer.escapeField("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVSanitizer.escapeField("line\nbreak"), "\"line\nbreak\"")
    }

    func testXMLEscaping() {
        XCTAssertEqual(XMLSanitizer.escapeText("a&b<c>d\"e'f"), "a&amp;b&lt;c&gt;d&quot;e&apos;f")
    }

    func testXMLFiltersInvalidScalars() {
        let cleaned = XMLSanitizer.escapeText("ok\u{0001}still")
        XCTAssertFalse(cleaned.contains("\u{0001}"))
        XCTAssertTrue(cleaned.contains("ok"))
        XCTAssertTrue(cleaned.contains("still"))
    }
}
