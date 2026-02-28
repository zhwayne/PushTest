import XCTest
@testable import PushTest

final class TokenMaskingTests: XCTestCase {
    func testMaskingOnlyRevealsLastFourCharacters() {
        let token = "abcdef123456"
        let masked = TokenMasking.masked(token)

        XCTAssertTrue(masked.hasSuffix("3456"))
        XCTAssertFalse(masked.contains("abcdef12"))
    }
}
