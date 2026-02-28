import XCTest
@testable import PushTest

final class P8KeyIDExtractorTests: XCTestCase {
    func testExtractReturnsKeyIDForStandardAuthKeyFileName() {
        let keyID = P8KeyIDExtractor.extract(fromFileName: "AuthKey_ABC123XYZ9.p8")
        XCTAssertEqual(keyID, "ABC123XYZ9")
    }

    func testExtractSupportsUppercaseExtension() {
        let keyID = P8KeyIDExtractor.extract(fromFileName: "AuthKey_QWER123456.P8")
        XCTAssertEqual(keyID, "QWER123456")
    }

    func testExtractReturnsNilForNonMatchingPattern() {
        XCTAssertNil(P8KeyIDExtractor.extract(fromFileName: "my_key_file.p8"))
        XCTAssertNil(P8KeyIDExtractor.extract(fromFileName: "AuthKey_.p8"))
        XCTAssertNil(P8KeyIDExtractor.extract(fromFileName: "AuthKey_ABC-123.p8"))
    }
}
