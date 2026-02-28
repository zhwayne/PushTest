import Foundation

enum LiveActivityPayloadTemplates {
    static func template(for event: LiveActivityEvent, timestamp: Int = Int(Date().timeIntervalSince1970)) -> String {
        let payload: [String: Any] = [
            "aps": apsPayload(for: event, timestamp: timestamp)
        ]

        return prettyPrintedJSON(payload) ?? "{}"
    }

    private static func apsPayload(for event: LiveActivityEvent, timestamp: Int) -> [String: Any] {
        switch event {
        case .start:
            return [
                "timestamp": timestamp,
                "event": event.rawValue,
                "attributes-type": "LiveActivityAttributes",
                "attributes": [
                    "id": "sample-id"
                ],
                "content-state": [
                    "status": "started",
                    "progress": 0
                ],
                "alert": [
                    "title": "Live Activity Started",
                    "body": "Push started this activity",
                    "sound": "default"
                ]
            ]
        case .update:
            return [
                "timestamp": timestamp,
                "event": event.rawValue,
                "content-state": [
                    "status": "updating",
                    "progress": 50
                ],
                "stale-date": timestamp + 60
            ]
        case .end:
            return [
                "timestamp": timestamp,
                "event": event.rawValue,
                "content-state": [
                    "status": "finished",
                    "progress": 100
                ],
                "dismissal-date": timestamp + 300
            ]
        }
    }

    private static func prettyPrintedJSON(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }
}
