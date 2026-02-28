import Foundation

final class APNsClient: APNsSending {
    private let session: URLSession
    private let jwtProvider: APNsJWTProvider
    private let requestBuilder: APNsRequestBuilder

    init(
        session: URLSession = .shared,
        jwtProvider: APNsJWTProvider = APNsJWTProvider(),
        requestBuilder: APNsRequestBuilder = APNsRequestBuilder()
    ) {
        self.session = session
        self.jwtProvider = jwtProvider
        self.requestBuilder = requestBuilder
    }

    func send(
        draft: PushRequestDraft,
        credentials: APNsCredentials,
        environment: APNsEnvironment
    ) async throws -> APNsSendResult {
        guard credentials.isValid else {
            throw APNSError.invalidCredentials
        }

        let jwt = try await jwtProvider.token(for: credentials)
        let builtRequest = try requestBuilder.buildRequest(
            draft: draft,
            credentials: credentials,
            environment: environment,
            jwt: jwt
        )

        let startedAt = Date()
        let (data, response) = try await session.data(for: builtRequest.request)
        let latency = Int(Date().timeIntervalSince(startedAt) * 1000)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APNSError.invalidHTTPResponse
        }

        let responseBody = String(data: data, encoding: .utf8)
        let reason = parseReason(from: data) ?? responseBody
        let apnsID = httpResponse.value(forHTTPHeaderField: "apns-id")

        return APNsSendResult(
            statusCode: httpResponse.statusCode,
            apnsID: apnsID,
            reason: reason,
            responseBody: responseBody,
            latencyMs: latency
        )
    }

    private func parseReason(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reason = json["reason"] as? String else {
            return nil
        }
        return reason
    }
}
