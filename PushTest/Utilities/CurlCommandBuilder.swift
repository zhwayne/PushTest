import Foundation

enum CurlCommandBuilder {
    static func build(
        environment: APNsEnvironment,
        token: String,
        topic: String,
        payloadJSON: String,
        priority: Int,
        collapseID: String?
    ) -> String {
        var headers = [
            "-H 'authorization: bearer <JWT>'",
            "-H 'apns-push-type: liveactivity'",
            "-H 'apns-topic: \(escapeSingleQuotes(topic))'",
            "-H 'apns-priority: \(priority)'"
        ]

        if let collapseID,
           !collapseID.isEmpty {
            headers.append("-H 'apns-collapse-id: \(escapeSingleQuotes(collapseID))'")
        }

        let url = "https://\(environment.host)/3/device/\(token)"
        let body = escapeSingleQuotes(payloadJSON)

        return (["curl --http2 -v", headers.joined(separator: " "), "-d '\(body)'", "'\(url)'"]).joined(separator: " ")
    }

    static func build(from record: PushHistoryRecord) -> String {
        build(
            environment: record.environment,
            token: record.deviceToken,
            topic: record.topic,
            payloadJSON: record.payloadJSON,
            priority: record.priority,
            collapseID: record.collapseID
        )
    }

    private static func escapeSingleQuotes(_ text: String) -> String {
        text.replacingOccurrences(of: "'", with: "'\\''")
    }
}
