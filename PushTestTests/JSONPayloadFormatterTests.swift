import Foundation
import XCTest
@testable import PushTest

final class JSONPayloadFormatterTests: XCTestCase {
    func testFormatPrettyPrintsAndSortsKeys() throws {
        let output = try JSONPayloadFormatter.format("{\"b\":1,\"a\":2}")

        XCTAssertTrue(output.contains("\n"))

        let aIndex = try XCTUnwrap(output.range(of: "\"a\"")?.lowerBound)
        let bIndex = try XCTUnwrap(output.range(of: "\"b\"")?.lowerBound)
        XCTAssertLessThan(aIndex, bIndex)
    }

    func testFormatUsesTwoSpaceIndentation() throws {
        let output = try JSONPayloadFormatter.format("{\"outer\":{\"inner\":1}}")
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertTrue(lines.contains("  \"outer\" : {"))
        XCTAssertTrue(lines.contains("    \"inner\" : 1"))
    }

    func testFormatIsIdempotent() throws {
        let once = try JSONPayloadFormatter.format("{\"z\":1,\"a\":{\"b\":2}}")
        let twice = try JSONPayloadFormatter.format(once)

        XCTAssertEqual(once, twice)
    }

    func testFormatRejectsInvalidJSON() {
        XCTAssertThrowsError(try JSONPayloadFormatter.format("{not-json}"))
    }
}
