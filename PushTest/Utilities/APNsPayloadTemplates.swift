import Foundation

enum APNsPayloadTemplates {
    static func template(
        pushType: APNsPushType,
        event: LiveActivityEvent,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> String {
        switch pushType {
        case .liveactivity:
            return LiveActivityPayloadTemplates.template(for: event, timestamp: timestamp)
        case .alert:
            return formattedJSON(alertTemplate())
        case .background:
            return formattedJSON(backgroundTemplate())
        }
    }

    private static func alertTemplate() -> [String: Any] {
        [
            "aps": [
                "alert": [
                    "title": "Notification Title",
                    "body": "Notification body from APNs"
                ],
                "badge": 1,
                "sound": "default"
            ]
        ]
    }

    private static func backgroundTemplate() -> [String: Any] {
        [
            "aps": [
                "content-available": 1
            ]
        ]
    }

    private static func formattedJSON(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let compact = String(data: data, encoding: .utf8),
              let formatted = try? JSONPayloadFormatter.format(compact) else {
            return "{}"
        }

        return formatted
    }
}
