import Foundation

struct PushRequestDraft {
    var event: LiveActivityEvent
    var pushType: APNsPushType
    var deviceToken: String
    var priority: Int
    var collapseID: String?
    var payloadJSON: String
    var topicOverride: String?

    var sanitizedDeviceToken: String {
        deviceToken
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedCollapseID: String? {
        collapseID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var normalizedTopicOverride: String? {
        topicOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
