import SwiftData
import XCTest
@testable import PushTest

@MainActor
final class PushHistoryStoreTests: XCTestCase {
    func testStorePrunesRecordsTo1000() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = PushHistoryStore(context: context)

        for index in 0..<1_005 {
            let draft = PushRequestDraft(
                event: .update,
                deviceToken: "token-\(index)",
                priority: 10,
                collapseID: nil,
                payloadJSON: LiveActivityPayloadTemplates.template(for: .update),
                topicOverride: nil
            )
            let result = APNsSendResult(statusCode: 200, apnsID: "id-\(index)", reason: nil, responseBody: nil, latencyMs: 1)

            try store.add(
                draft: draft,
                environment: .sandbox,
                topic: "com.example.app.push-type.liveactivity",
                result: result,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let count = try context.fetchCount(FetchDescriptor<PushHistoryRecord>())
        XCTAssertEqual(count, 1_000)

        let oldestDescriptor = FetchDescriptor<PushHistoryRecord>(
            sortBy: [SortDescriptor(\PushHistoryRecord.createdAt, order: .forward)]
        )
        let oldest = try XCTUnwrap(try context.fetch(oldestDescriptor).first)
        XCTAssertEqual(Int(oldest.createdAt.timeIntervalSince1970), 5)
    }

    func testStorePersistsTopicOverrideInputWhenPresent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = PushHistoryStore(context: context)

        let draft = PushRequestDraft(
            event: .update,
            deviceToken: "token-present",
            priority: 10,
            collapseID: nil,
            payloadJSON: LiveActivityPayloadTemplates.template(for: .update),
            topicOverride: "custom.topic.override"
        )
        let result = APNsSendResult(statusCode: 200, apnsID: "id-present", reason: nil, responseBody: nil, latencyMs: 1)

        try store.add(
            draft: draft,
            environment: .sandbox,
            topic: "custom.topic.override",
            result: result
        )

        let descriptor = FetchDescriptor<PushHistoryRecord>(
            sortBy: [SortDescriptor(\PushHistoryRecord.createdAt, order: .reverse)]
        )
        let record = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(record.topicOverrideInput, "custom.topic.override")
    }

    func testStorePersistsCredentialSnapshotWhenPresent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = PushHistoryStore(context: context)

        let draft = PushRequestDraft(
            event: .update,
            deviceToken: "token-creds",
            priority: 10,
            collapseID: nil,
            payloadJSON: LiveActivityPayloadTemplates.template(for: .update),
            topicOverride: nil
        )
        let result = APNsSendResult(statusCode: 200, apnsID: "id-creds", reason: nil, responseBody: nil, latencyMs: 1)

        try store.add(
            draft: draft,
            environment: .sandbox,
            topic: "com.example.app.push-type.liveactivity",
            result: result,
            credentialTeamID: "TEAM12345",
            credentialKeyID: "KEY12345",
            credentialBundleID: "com.example.app"
        )

        let descriptor = FetchDescriptor<PushHistoryRecord>(
            sortBy: [SortDescriptor(\PushHistoryRecord.createdAt, order: .reverse)]
        )
        let record = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(record.credentialTeamID, "TEAM12345")
        XCTAssertEqual(record.credentialKeyID, "KEY12345")
        XCTAssertEqual(record.credentialBundleID, "com.example.app")
    }

    func testStorePersistsNilTopicOverrideInputWhenAbsent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = PushHistoryStore(context: context)

        let draft = PushRequestDraft(
            event: .update,
            deviceToken: "token-missing",
            priority: 10,
            collapseID: nil,
            payloadJSON: LiveActivityPayloadTemplates.template(for: .update),
            topicOverride: nil
        )
        let result = APNsSendResult(statusCode: 200, apnsID: "id-missing", reason: nil, responseBody: nil, latencyMs: 1)

        try store.add(
            draft: draft,
            environment: .sandbox,
            topic: "com.example.app.push-type.liveactivity",
            result: result
        )

        let descriptor = FetchDescriptor<PushHistoryRecord>(
            sortBy: [SortDescriptor(\PushHistoryRecord.createdAt, order: .reverse)]
        )
        let record = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertNil(record.topicOverrideInput)
    }

    func testStoreAllowsNilCredentialAndP8PathForCompatibility() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = PushHistoryStore(context: context)

        let draft = PushRequestDraft(
            event: .update,
            deviceToken: "token-legacy",
            priority: 10,
            collapseID: nil,
            payloadJSON: LiveActivityPayloadTemplates.template(for: .update),
            topicOverride: nil
        )
        let result = APNsSendResult(statusCode: 200, apnsID: "id-legacy", reason: nil, responseBody: nil, latencyMs: 1)

        try store.add(
            draft: draft,
            environment: .sandbox,
            topic: "com.example.app.push-type.liveactivity",
            result: result
        )

        let descriptor = FetchDescriptor<PushHistoryRecord>(
            sortBy: [SortDescriptor(\PushHistoryRecord.createdAt, order: .reverse)]
        )
        let record = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertNil(record.credentialTeamID)
        XCTAssertNil(record.credentialKeyID)
        XCTAssertNil(record.credentialBundleID)
        XCTAssertNil(record.p8FilePath)
        XCTAssertNil(record.p8BookmarkData)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([PushHistoryRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
