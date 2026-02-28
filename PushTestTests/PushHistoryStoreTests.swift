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

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([PushHistoryRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
