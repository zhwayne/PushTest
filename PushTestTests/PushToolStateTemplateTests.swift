import XCTest
@testable import PushTest

@MainActor
final class PushToolStateTemplateTests: XCTestCase {
    private static var retainedStates: [PushToolState] = []

    func testInitialStateDefaultsToAlertTemplate() throws {
        let state = makeState()

        XCTAssertEqual(state.pushType, .alert)

        let root = try jsonObject(from: state.payloadJSON)
        let aps = try dictionaryValue(for: "aps", in: root)
        _ = try dictionaryValue(for: "alert", in: aps)
    }

    func testChangingPushTypeAutoAppliesTemplate() throws {
        let state = makeState()
        state.payloadJSON = "{\"custom\":true}"

        state.pushType = .background

        let root = try jsonObject(from: state.payloadJSON)
        let aps = try dictionaryValue(for: "aps", in: root)
        XCTAssertEqual((aps["content-available"] as? NSNumber)?.intValue, 1)
    }

    func testChangingLiveActivityEventAutoAppliesTemplate() throws {
        let state = makeState()
        state.pushType = .liveactivity

        state.event = .end

        let root = try jsonObject(from: state.payloadJSON)
        let aps = try dictionaryValue(for: "aps", in: root)
        XCTAssertEqual(aps["event"] as? String, "end")
    }

    func testReplayDoesNotOverwriteHistoricalPayload() {
        let state = makeState()
        let historicalPayload = "{\"aps\":{\"content-available\":1},\"from\":\"history\"}"
        let record = makeRecord(
            pushTypeRaw: APNsPushType.background.rawValue,
            event: .update,
            payloadJSON: historicalPayload
        )

        state.loadFromHistory(record)

        XCTAssertEqual(state.pushType, .background)
        XCTAssertEqual(state.payloadJSON, historicalPayload)
    }

    func testResetSendFormToDefaultsClearsCredentialsTargetPayloadAndResult() throws {
        let state = makeState()
        state.teamID = "TEAM12345"
        state.keyID = "KEY12345"
        state.bundleID = "com.example.bundle"
        state.p8PEM = "pem"
        state.importedP8Filename = "AuthKey_KEY12345.p8"
        state.environment = .production
        state.pushType = .liveactivity
        state.event = .update
        state.deviceToken = "token"
        state.priority = 5
        state.collapseID = "collapse"
        state.topicOverride = "custom.topic"
        state.payloadJSON = "{\"custom\":true}"
        state.validationErrors = ["invalid"]
        state.result = APNsSendResult(statusCode: 400, apnsID: "id", reason: "BadRequest", responseBody: nil, latencyMs: 10)
        state.requestTopic = "custom.topic"
        state.sendErrorMessage = "error"
        state.infoMessage = "info"

        state.resetSendFormToDefaults()

        XCTAssertEqual(state.teamID, "")
        XCTAssertEqual(state.keyID, "")
        XCTAssertEqual(state.bundleID, "")
        XCTAssertEqual(state.p8PEM, "")
        XCTAssertNil(state.importedP8Filename)
        XCTAssertEqual(state.environment, .sandbox)
        XCTAssertEqual(state.pushType, .alert)
        XCTAssertEqual(state.event, .start)
        XCTAssertEqual(state.deviceToken, "")
        XCTAssertEqual(state.priority, 10)
        XCTAssertEqual(state.collapseID, "")
        XCTAssertEqual(state.topicOverride, "")
        XCTAssertTrue(state.validationErrors.isEmpty)
        XCTAssertNil(state.result)
        XCTAssertNil(state.requestTopic)
        XCTAssertNil(state.sendErrorMessage)
        XCTAssertNil(state.infoMessage)

        let root = try jsonObject(from: state.payloadJSON)
        let aps = try dictionaryValue(for: "aps", in: root)
        _ = try dictionaryValue(for: "alert", in: aps)
    }

    func testResetSendFormToDefaultsUsesAlertTemplate() throws {
        let state = makeState()
        state.pushType = .background
        state.payloadJSON = "{\"aps\":{\"content-available\":1}}"

        state.resetSendFormToDefaults()

        XCTAssertEqual(state.pushType, .alert)
        let root = try jsonObject(from: state.payloadJSON)
        let aps = try dictionaryValue(for: "aps", in: root)
        _ = try dictionaryValue(for: "alert", in: aps)
    }

    func testResetSendFormToDefaultsKeepsSelectedTabUnchanged() {
        let state = makeState()
        state.selectedTab = .history

        state.resetSendFormToDefaults()

        XCTAssertEqual(state.selectedTab, .history)
    }

    func testTemplateOverwriteGuardReturnsFalseForEmptyPayload() {
        let state = makeState()
        state.payloadJSON = "   \n"

        XCTAssertFalse(state.requiresTemplateOverwriteConfirmation())
    }

    func testTemplateOverwriteGuardReturnsFalseWhenPayloadMatchesCurrentTemplate() throws {
        let state = makeState()
        state.payloadJSON = try compactJSON(from: state.payloadJSON)

        XCTAssertTrue(state.payloadMatchesCurrentTemplate())
        XCTAssertFalse(state.requiresTemplateOverwriteConfirmation())
    }

    func testTemplateOverwriteGuardReturnsTrueWhenPayloadIsModified() {
        let state = makeState()
        state.payloadJSON = """
        {
          "aps": {
            "alert": {
              "title": "Changed title",
              "body": "Changed body"
            },
            "sound": "default"
          }
        }
        """

        XCTAssertFalse(state.payloadMatchesCurrentTemplate())
        XCTAssertTrue(state.requiresTemplateOverwriteConfirmation())
    }

    func testTemplateOverwriteGuardReturnsTrueForNonEmptyInvalidJSON() {
        let state = makeState()
        state.payloadJSON = "{ this is invalid json"

        XCTAssertFalse(state.payloadMatchesCurrentTemplate())
        XCTAssertTrue(state.requiresTemplateOverwriteConfirmation())
    }

    private func makeRecord(
        pushTypeRaw: String,
        event: LiveActivityEvent,
        payloadJSON: String
    ) -> PushHistoryRecord {
        PushHistoryRecord(
            createdAt: .now,
            event: event,
            environment: .sandbox,
            deviceToken: "token",
            tokenMasked: TokenMasking.masked("token"),
            topic: "com.example.app",
            pushTypeRaw: pushTypeRaw,
            topicOverrideInput: nil,
            payloadJSON: payloadJSON,
            priority: 10,
            collapseID: nil,
            statusCode: 200,
            apnsID: nil,
            reason: nil,
            responseBody: nil,
            latencyMs: 1
        )
    }

    private func jsonObject(from text: String) throws -> [String: Any] {
        let data = try XCTUnwrap(text.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return try XCTUnwrap(object as? [String: Any])
    }

    private func dictionaryValue(for key: String, in object: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap(object[key] as? [String: Any])
    }

    private func compactJSON(from text: String) throws -> String {
        let data = try XCTUnwrap(text.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let compactData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try XCTUnwrap(String(data: compactData, encoding: .utf8))
    }

    private func makeState() -> PushToolState {
        let state = PushToolState()
        Self.retainedStates.append(state)
        return state
    }
}
