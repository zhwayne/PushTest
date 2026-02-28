import Foundation

enum PayloadValidator {
    static func validate(payloadJSON: String, event: LiveActivityEvent) -> [String] {
        var errors: [String] = []

        guard let data = payloadJSON.data(using: .utf8) else {
            return ["Payload is not valid UTF-8."]
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["Payload is not valid JSON."]
        }

        guard let aps = root["aps"] as? [String: Any] else {
            return ["Missing aps object."]
        }

        if !(aps["timestamp"] is NSNumber) {
            errors.append("aps.timestamp is required and must be a number.")
        }

        guard let payloadEvent = aps["event"] as? String else {
            errors.append("aps.event is required.")
            return errors
        }

        if payloadEvent != event.rawValue {
            errors.append("aps.event must match selected event \(event.rawValue).")
        }

        switch event {
        case .start:
            if !(aps["attributes-type"] is String) {
                errors.append("aps.attributes-type is required for start.")
            }
            if !(aps["attributes"] is [String: Any]) {
                errors.append("aps.attributes is required for start and must be an object.")
            }
            if !(aps["content-state"] is [String: Any]) {
                errors.append("aps.content-state is required for start and must be an object.")
            }
        case .update:
            if !(aps["content-state"] is [String: Any]) {
                errors.append("aps.content-state is required for update and must be an object.")
            }
        case .end:
            if !(aps["content-state"] is [String: Any]) {
                errors.append("aps.content-state is required for end and must be an object.")
            }
        }

        return errors
    }
}
