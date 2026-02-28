import XCTest
@testable import PushTest

final class JSONSyntaxHighlighterTests: XCTestCase {
    func testAttributedStringKeepsInputText() {
        let highlighter = JSONSyntaxHighlighter.shared
        let input = "{\"name\":\"demo\",\"active\":true,\"count\":3}"

        let attributed = highlighter.attributedString(for: input, baseAttributes: [:])
        XCTAssertEqual(attributed.string, input)
    }

    func testHighlightGracefullySkipsLargePayloads() {
        let highlighter = JSONSyntaxHighlighter.shared
        let input = String(repeating: "{}", count: highlighter.maximumLength + 1)

        XCTAssertNil(highlighter.highlight(text: input))
    }
}
