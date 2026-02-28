import XCTest
@testable import PushTest

final class JSONAutoIndentEngineTests: XCTestCase {
    private enum MarkerError: Error {
        case missingCursorMarker
    }

    func testNewlineAfterOpeningBraceAddsIndentLevel() throws {
        let result = try applyInsertion(to: "{|")
        XCTAssertEqual(result, "{\n  |")
    }

    func testNewlineKeepsCurrentLineIndentation() throws {
        let result = try applyInsertion(to: "{\n  \"name\": \"demo\",|")
        XCTAssertEqual(result, "{\n  \"name\": \"demo\",\n  |")
    }

    func testNewlineBetweenBracesCreatesIndentedLineAndClosingAlignment() throws {
        let result = try applyInsertion(to: "{|}")
        XCTAssertEqual(result, "{\n  |\n}")
    }

    func testNewlineBetweenBracketsCreatesIndentedLineAndClosingAlignment() throws {
        let result = try applyInsertion(to: "[|]")
        XCTAssertEqual(result, "[\n  |\n]")
    }

    func testInsertionReturnsNilWhenSelectionIsNotCollapsed() {
        XCTAssertNil(
            JSONAutoIndentEngine.insertion(
                for: "{\"value\":1}",
                selectedRange: NSRange(location: 1, length: 1)
            )
        )
    }

    private func applyInsertion(to markedText: String) throws -> String {
        let (text, selectedRange) = try parseMarkedText(markedText)
        let insertion = try XCTUnwrap(
            JSONAutoIndentEngine.insertion(for: text, selectedRange: selectedRange)
        )

        let updated = (text as NSString).replacingCharacters(in: selectedRange, with: insertion.text)
        return withCursorMarker(in: updated, location: selectedRange.location + insertion.cursorOffset)
    }

    private func parseMarkedText(_ text: String) throws -> (String, NSRange) {
        let markerRange = (text as NSString).range(of: "|")
        guard markerRange.location != NSNotFound else {
            throw MarkerError.missingCursorMarker
        }

        let withoutMarker = (text as NSString).replacingCharacters(in: markerRange, with: "")
        return (withoutMarker, NSRange(location: markerRange.location, length: 0))
    }

    private func withCursorMarker(in text: String, location: Int) -> String {
        (text as NSString).replacingCharacters(in: NSRange(location: location, length: 0), with: "|")
    }
}
