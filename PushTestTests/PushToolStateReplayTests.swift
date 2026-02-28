import XCTest
@testable import PushTest

@MainActor
final class PushToolStateReplayTests: XCTestCase {
    private static var retainedStates: [PushToolState] = []

    func testReplayFillsAllRequestFields() {
        let state = makeState()
        state.selectedTab = .history
        state.environment = .production
        state.pushType = .background
        state.event = .end
        state.deviceToken = "old-token"
        state.priority = 5
        state.collapseID = "old-collapse"
        state.topicOverride = "old.topic"
        state.teamID = "OLDTEAM"
        state.keyID = "OLDKEY"
        state.bundleID = "old.bundle"
        state.payloadJSON = "{}"

        let record = makeRecord(
            environment: .sandbox,
            event: .update,
            token: "replay-token",
            priority: 10,
            collapseID: "collapse-123",
            topic: "com.example.app.push-type.liveactivity",
            pushTypeRaw: APNsPushType.background.rawValue,
            topicOverrideInput: "custom.topic",
            credentialTeamID: "TEAM12345",
            credentialKeyID: "KEY12345",
            credentialBundleID: "com.example.app",
            payloadJSON: "{\"aps\":{\"event\":\"update\",\"timestamp\":1700000000,\"content-state\":{\"value\":1}}}"
        )

        state.loadFromHistory(record)

        XCTAssertEqual(state.selectedTab, .send)
        XCTAssertEqual(state.environment, .sandbox)
        XCTAssertEqual(state.pushType, .background)
        XCTAssertEqual(state.event, .update)
        XCTAssertEqual(state.deviceToken, "replay-token")
        XCTAssertEqual(state.priority, 10)
        XCTAssertEqual(state.collapseID, "collapse-123")
        XCTAssertEqual(state.topicOverride, "custom.topic")
        XCTAssertEqual(state.teamID, "TEAM12345")
        XCTAssertEqual(state.keyID, "KEY12345")
        XCTAssertEqual(state.bundleID, "com.example.app")
        XCTAssertEqual(
            state.payloadJSON,
            "{\"aps\":{\"event\":\"update\",\"timestamp\":1700000000,\"content-state\":{\"value\":1}}}"
        )
    }

    func testReplayClearsResultSectionState() {
        let state = makeState()
        state.result = APNsSendResult(
            statusCode: 403,
            apnsID: "old-apns-id",
            reason: "Forbidden",
            responseBody: "{\"reason\":\"Forbidden\"}",
            latencyMs: 250
        )
        state.requestTopic = "old.topic"
        state.sendErrorMessage = "old error"
        state.infoMessage = "old info"
        state.validationErrors = ["old validation"]

        let record = makeRecord(topicOverrideInput: "new.topic")
        state.loadFromHistory(record)

        XCTAssertNil(state.result)
        XCTAssertNil(state.requestTopic)
        XCTAssertNil(state.sendErrorMessage)
        XCTAssertNil(state.infoMessage)
        XCTAssertTrue(state.validationErrors.isEmpty)
        XCTAssertEqual(state.pushType, .liveactivity)
    }

    func testReplayDoesNotAutoImportP8EvenWhenHistoryContainsPathOrBookmark() throws {
        let state = makeState()
        state.p8PEM = "existing-p8"
        state.importedP8Filename = "existing.p8"

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let p8URL = tempDirectory.appendingPathComponent("AuthKey_TESTKEYID.p8")
        let pemText = """
        -----BEGIN PRIVATE KEY-----
        TEST-PRIVATE-KEY
        -----END PRIVATE KEY-----
        """
        try pemText.write(to: p8URL, atomically: true, encoding: .utf8)
        let bookmarkData = try p8URL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let record = makeRecord(
            pushTypeRaw: APNsPushType.alert.rawValue,
            topicOverrideInput: "custom.topic",
            credentialTeamID: "TEAM12345",
            credentialKeyID: "TESTKEYID",
            credentialBundleID: "com.example.app",
            p8FilePath: p8URL.path,
            p8BookmarkData: bookmarkData
        )

        state.loadFromHistory(record)

        XCTAssertEqual(state.teamID, "TEAM12345")
        XCTAssertEqual(state.keyID, "TESTKEYID")
        XCTAssertEqual(state.bundleID, "com.example.app")
        XCTAssertEqual(state.pushType, .alert)
        XCTAssertEqual(state.p8PEM, "")
        XCTAssertNil(state.importedP8Filename)
    }

    func testReplayClearsCredentialsWhenLegacyRecordMissingSnapshot() {
        let state = makeState()
        state.teamID = "EXISTINGTEAM"
        state.keyID = "EXISTINGKEY"
        state.bundleID = "existing.bundle"
        state.p8PEM = "existing-p8"
        state.importedP8Filename = "existing.p8"

        let record = makeRecord(topicOverrideInput: "custom.topic")
        state.loadFromHistory(record)

        XCTAssertEqual(state.teamID, "")
        XCTAssertEqual(state.keyID, "")
        XCTAssertEqual(state.bundleID, "")
        XCTAssertEqual(state.pushType, .liveactivity)
        XCTAssertEqual(state.p8PEM, "")
        XCTAssertNil(state.importedP8Filename)
    }

    func testReplayTopicOverrideFallsBackToEmptyWhenMissingInput() {
        let state = makeState()
        let record = makeRecord(
            topic: "com.example.app.push-type.liveactivity",
            topicOverrideInput: nil
        )

        state.loadFromHistory(record)

        XCTAssertEqual(state.topicOverride, "")
    }

    func testReplayFallsBackToAlertWhenHistoryPushTypeMissing() {
        let state = makeState()
        state.pushType = .background

        let record = makeRecord(
            pushTypeRaw: nil,
            topicOverrideInput: "topic"
        )

        state.loadFromHistory(record)

        XCTAssertEqual(state.pushType, .alert)
    }

    private func makeRecord(
        environment: APNsEnvironment = .sandbox,
        event: LiveActivityEvent = .start,
        token: String = "token-default",
        priority: Int = 10,
        collapseID: String? = nil,
        topic: String = "com.example.app.push-type.liveactivity",
        pushTypeRaw: String? = APNsPushType.liveactivity.rawValue,
        topicOverrideInput: String?,
        credentialTeamID: String? = nil,
        credentialKeyID: String? = nil,
        credentialBundleID: String? = nil,
        p8FilePath: String? = nil,
        p8BookmarkData: Data? = nil,
        payloadJSON: String? = nil
    ) -> PushHistoryRecord {
        let resolvedPayloadJSON = payloadJSON ?? LiveActivityPayloadTemplates.template(for: .start)

        return PushHistoryRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            event: event,
            environment: environment,
            deviceToken: token,
            tokenMasked: TokenMasking.masked(token),
            topic: topic,
            pushTypeRaw: pushTypeRaw,
            topicOverrideInput: topicOverrideInput,
            credentialTeamID: credentialTeamID,
            credentialKeyID: credentialKeyID,
            credentialBundleID: credentialBundleID,
            p8FilePath: p8FilePath,
            p8BookmarkData: p8BookmarkData,
            payloadJSON: resolvedPayloadJSON,
            priority: priority,
            collapseID: collapseID,
            statusCode: 200,
            apnsID: "apns-id",
            reason: nil,
            responseBody: nil,
            latencyMs: 80
        )
    }

    private func makeState() -> PushToolState {
        let state = PushToolState()
        Self.retainedStates.append(state)
        return state
    }

}
