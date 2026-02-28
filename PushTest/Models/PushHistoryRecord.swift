import Foundation
import SwiftData

@Model
final class PushHistoryRecord {
    var createdAt: Date
    var eventRaw: String
    var environmentRaw: String
    var deviceToken: String
    var tokenMasked: String
    var topic: String
    var payloadJSON: String
    var priority: Int
    var collapseID: String?
    var statusCode: Int
    var apnsID: String?
    var reason: String?
    var responseBody: String?
    var latencyMs: Int

    init(
        createdAt: Date,
        event: LiveActivityEvent,
        environment: APNsEnvironment,
        deviceToken: String,
        tokenMasked: String,
        topic: String,
        payloadJSON: String,
        priority: Int,
        collapseID: String?,
        statusCode: Int,
        apnsID: String?,
        reason: String?,
        responseBody: String?,
        latencyMs: Int
    ) {
        self.createdAt = createdAt
        self.eventRaw = event.rawValue
        self.environmentRaw = environment.rawValue
        self.deviceToken = deviceToken
        self.tokenMasked = tokenMasked
        self.topic = topic
        self.payloadJSON = payloadJSON
        self.priority = priority
        self.collapseID = collapseID
        self.statusCode = statusCode
        self.apnsID = apnsID
        self.reason = reason
        self.responseBody = responseBody
        self.latencyMs = latencyMs
    }

    var event: LiveActivityEvent {
        get { LiveActivityEvent(rawValue: eventRaw) ?? .update }
        set { eventRaw = newValue.rawValue }
    }

    var environment: APNsEnvironment {
        get { APNsEnvironment(rawValue: environmentRaw) ?? .sandbox }
        set { environmentRaw = newValue.rawValue }
    }
}
