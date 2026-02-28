import XCTest
@testable import PushTest

final class CurlCommandBuilderTests: XCTestCase {
    func testBuildIncludesSelectedPushTypeHeader() {
        let command = CurlCommandBuilder.build(
            environment: .sandbox,
            pushType: .background,
            token: "token123",
            topic: "com.example.app",
            payloadJSON: "{\"aps\":{\"content-available\":1}}",
            priority: 5,
            collapseID: nil
        )

        XCTAssertTrue(command.contains("apns-push-type: background"))
    }

    func testBuildFromRecordUsesPersistedPushType() {
        let record = PushHistoryRecord(
            createdAt: .now,
            event: .update,
            environment: .production,
            deviceToken: "token-record",
            tokenMasked: "*******cord",
            topic: "com.example.app",
            pushTypeRaw: APNsPushType.alert.rawValue,
            topicOverrideInput: nil,
            payloadJSON: "{\"aps\":{}}",
            priority: 10,
            collapseID: "collapse-1",
            statusCode: 200,
            apnsID: "id-1",
            reason: nil,
            responseBody: nil,
            latencyMs: 1
        )

        let command = CurlCommandBuilder.build(from: record)

        XCTAssertTrue(command.contains("apns-push-type: alert"))
        XCTAssertTrue(command.contains("https://api.push.apple.com/3/device/token-record"))
    }
}
