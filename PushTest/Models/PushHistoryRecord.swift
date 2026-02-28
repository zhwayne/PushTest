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
    var pushTypeRaw: String?
    var topicOverrideInput: String?
    var credentialTeamID: String?
    var credentialKeyID: String?
    var credentialBundleID: String?
    var p8FilePath: String?
    var p8BookmarkData: Data?
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
        pushTypeRaw: String? = nil,
        topicOverrideInput: String?,
        credentialTeamID: String? = nil,
        credentialKeyID: String? = nil,
        credentialBundleID: String? = nil,
        p8FilePath: String? = nil,
        p8BookmarkData: Data? = nil,
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
        self.pushTypeRaw = pushTypeRaw
        self.topicOverrideInput = topicOverrideInput
        self.credentialTeamID = credentialTeamID
        self.credentialKeyID = credentialKeyID
        self.credentialBundleID = credentialBundleID
        self.p8FilePath = p8FilePath
        self.p8BookmarkData = p8BookmarkData
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

    var pushType: APNsPushType {
        get { APNsPushType(rawValue: pushTypeRaw ?? "") ?? .alert }
        set { pushTypeRaw = newValue.rawValue }
    }

    var unsupportedPushTypeRaw: String? {
        guard let raw = pushTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        return APNsPushType(rawValue: raw) == nil ? raw : nil
    }
}
