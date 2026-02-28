import XCTest
@testable import PushTest

final class APNsRequestBuilderTests: XCTestCase {
    func testBuildRequestSetsURLAndHeaders() throws {
        let builder = APNsRequestBuilder()
        let credentials = TestFixtures.makeCredentials(bundleID: "com.example.app")
        let draft = PushRequestDraft(
            event: .update,
            pushType: .liveactivity,
            deviceToken: "<abc123>",
            priority: 5,
            collapseID: "sync-1",
            payloadJSON: LiveActivityPayloadTemplates.template(for: .update),
            topicOverride: nil
        )

        let built = try builder.buildRequest(
            draft: draft,
            credentials: credentials,
            environment: .sandbox,
            jwt: "jwt-token"
        )

        XCTAssertEqual(built.request.url?.absoluteString, "https://api.sandbox.push.apple.com/3/device/abc123")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "authorization"), "bearer jwt-token")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "apns-push-type"), "liveactivity")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "apns-topic"), "com.example.app.push-type.liveactivity")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "apns-priority"), "5")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "apns-collapse-id"), "sync-1")
    }

    func testBuildRequestUsesTopicOverride() throws {
        let builder = APNsRequestBuilder()
        let credentials = TestFixtures.makeCredentials(bundleID: "com.example.app")
        let draft = PushRequestDraft(
            event: .end,
            pushType: .alert,
            deviceToken: "abcd",
            priority: 10,
            collapseID: nil,
            payloadJSON: LiveActivityPayloadTemplates.template(for: .end),
            topicOverride: "custom.topic"
        )

        let built = try builder.buildRequest(
            draft: draft,
            credentials: credentials,
            environment: .production,
            jwt: "jwt"
        )

        XCTAssertEqual(built.topic, "custom.topic")
        XCTAssertEqual(built.request.url?.absoluteString, "https://api.push.apple.com/3/device/abcd")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "apns-push-type"), "alert")
    }

    func testBuildRequestUsesBundleIDAsDefaultTopicForNonLiveActivity() throws {
        let builder = APNsRequestBuilder()
        let credentials = TestFixtures.makeCredentials(bundleID: "com.example.app")
        let draft = PushRequestDraft(
            event: .update,
            pushType: .background,
            deviceToken: "xyz",
            priority: 5,
            collapseID: nil,
            payloadJSON: "{\"aps\":{\"content-available\":1}}",
            topicOverride: nil
        )

        let built = try builder.buildRequest(
            draft: draft,
            credentials: credentials,
            environment: .sandbox,
            jwt: "jwt"
        )

        XCTAssertEqual(built.topic, "com.example.app")
        XCTAssertEqual(built.request.value(forHTTPHeaderField: "apns-push-type"), "background")
    }
}
