import Foundation

struct APNsBuiltRequest {
    var request: URLRequest
    var topic: String
}

struct APNsRequestBuilder {
    func buildRequest(
        draft: PushRequestDraft,
        credentials: APNsCredentials,
        environment: APNsEnvironment,
        jwt: String
    ) throws -> APNsBuiltRequest {
        let token = draft.sanitizedDeviceToken
        guard !token.isEmpty else {
            throw APNSError.invalidDeviceToken
        }

        guard let payloadData = draft.payloadJSON.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: payloadData)) != nil else {
            throw APNSError.invalidPayload
        }

        let topic = draft.normalizedTopicOverride ?? "\(credentials.bundleID).push-type.liveactivity"

        let endpoint = environment.baseURL.appending(path: "/3/device/\(token)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.timeoutInterval = 30

        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("liveactivity", forHTTPHeaderField: "apns-push-type")
        request.setValue(topic, forHTTPHeaderField: "apns-topic")
        request.setValue("\(draft.priority)", forHTTPHeaderField: "apns-priority")

        if let collapseID = draft.normalizedCollapseID {
            request.setValue(collapseID, forHTTPHeaderField: "apns-collapse-id")
        }

        return APNsBuiltRequest(request: request, topic: topic)
    }
}
