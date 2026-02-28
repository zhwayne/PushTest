import XCTest
@testable import PushTest

final class APNsPayloadTemplatesTests: XCTestCase {
    func testAllPushTypesProduceValidJSON() throws {
        for pushType in APNsPushType.allCases {
            let payload = APNsPayloadTemplates.template(pushType: pushType, event: .start, timestamp: 1_700_000_000)
            XCTAssertNotNil(try jsonObject(from: payload))
        }
    }

    func testLiveActivityTemplateTracksSelectedEvent() throws {
        for event in LiveActivityEvent.allCases {
            let payload = APNsPayloadTemplates.template(pushType: .liveactivity, event: event, timestamp: 1_700_000_000)
            let root = try jsonObject(from: payload)
            let aps = try dictionaryValue(for: "aps", in: root)
            XCTAssertEqual(aps["event"] as? String, event.rawValue)
        }
    }

    func testAlertTemplateContainsAppleAlertFields() throws {
        let payload = APNsPayloadTemplates.template(pushType: .alert, event: .start, timestamp: 1_700_000_000)
        let root = try jsonObject(from: payload)
        let aps = try dictionaryValue(for: "aps", in: root)
        let alert = try dictionaryValue(for: "alert", in: aps)

        XCTAssertEqual(alert["title"] as? String, "Notification Title")
        XCTAssertEqual(alert["body"] as? String, "Notification body from APNs")
        XCTAssertEqual((aps["badge"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(aps["sound"] as? String, "default")
    }

    func testBackgroundTemplateContainsContentAvailable() throws {
        let payload = APNsPayloadTemplates.template(pushType: .background, event: .start, timestamp: 1_700_000_000)
        let root = try jsonObject(from: payload)
        let aps = try dictionaryValue(for: "aps", in: root)

        XCTAssertEqual((aps["content-available"] as? NSNumber)?.intValue, 1)
    }

    private func jsonObject(from text: String) throws -> [String: Any] {
        let data = try XCTUnwrap(text.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return try XCTUnwrap(object as? [String: Any])
    }

    private func dictionaryValue(for key: String, in object: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap(object[key] as? [String: Any])
    }
}
