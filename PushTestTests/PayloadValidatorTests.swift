import XCTest
@testable import PushTest

final class PayloadValidatorTests: XCTestCase {
    func testInvalidJSONFailsValidation() {
        let errors = PayloadValidator.validate(payloadJSON: "{not-json}", event: .start, pushType: .liveactivity)
        XCTAssertFalse(errors.isEmpty)
    }

    func testMismatchedEventFailsValidation() {
        let payload = LiveActivityPayloadTemplates.template(for: .update)
        let errors = PayloadValidator.validate(payloadJSON: payload, event: .start, pushType: .liveactivity)

        XCTAssertTrue(errors.contains { $0.localizedStandardContains("must match selected event") })
    }

    func testStartRequiresAttributesAndContentState() {
        let payload = """
        {
          "aps": {
            "timestamp": 1700000000,
            "event": "start"
          }
        }
        """

        let errors = PayloadValidator.validate(payloadJSON: payload, event: .start, pushType: .liveactivity)
        XCTAssertEqual(errors.count, 3)
    }

    func testUpdateWithValidPayloadPassesValidation() {
        let payload = LiveActivityPayloadTemplates.template(for: .update)
        let errors = PayloadValidator.validate(payloadJSON: payload, event: .update, pushType: .liveactivity)

        XCTAssertTrue(errors.isEmpty)
    }

    func testEndRequiresContentState() {
        let payload = """
        {
          "aps": {
            "timestamp": 1700000000,
            "event": "end"
          }
        }
        """

        let errors = PayloadValidator.validate(payloadJSON: payload, event: .end, pushType: .liveactivity)
        XCTAssertTrue(errors.contains { $0.localizedStandardContains("content-state") })
    }

    func testNonLiveActivityOnlyValidatesJSONStructure() {
        let payload = "{\"message\":\"hello\"}"
        let errors = PayloadValidator.validate(payloadJSON: payload, event: .start, pushType: .background)

        XCTAssertTrue(errors.isEmpty)
    }
}
