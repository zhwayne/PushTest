import Foundation
import SwiftData

@MainActor
struct PushHistoryStore {
    static let maxRecords = 1000

    var context: ModelContext

    func add(
        draft: PushRequestDraft,
        environment: APNsEnvironment,
        topic: String,
        result: APNsSendResult,
        createdAt: Date = .now
    ) throws {
        let record = PushHistoryRecord(
            createdAt: createdAt,
            event: draft.event,
            environment: environment,
            deviceToken: draft.sanitizedDeviceToken,
            tokenMasked: TokenMasking.masked(draft.sanitizedDeviceToken),
            topic: topic,
            payloadJSON: draft.payloadJSON,
            priority: draft.priority,
            collapseID: draft.normalizedCollapseID,
            statusCode: result.statusCode,
            apnsID: result.apnsID,
            reason: result.reason,
            responseBody: result.responseBody,
            latencyMs: result.latencyMs
        )

        context.insert(record)
        try context.save()
        try pruneIfNeeded(limit: Self.maxRecords)
    }

    func pruneIfNeeded(limit: Int) throws {
        let descriptor = FetchDescriptor<PushHistoryRecord>(
            sortBy: [SortDescriptor(\PushHistoryRecord.createdAt, order: .reverse)]
        )

        let records = try context.fetch(descriptor)
        guard records.count > limit else { return }

        records.dropFirst(limit).forEach { context.delete($0) }
        try context.save()
    }

    func clearAll() throws {
        let descriptor = FetchDescriptor<PushHistoryRecord>()
        let records = try context.fetch(descriptor)
        records.forEach { context.delete($0) }
        try context.save()
    }
}
