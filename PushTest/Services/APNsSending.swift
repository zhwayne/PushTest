import Foundation

protocol APNsSending {
    func send(
        draft: PushRequestDraft,
        credentials: APNsCredentials,
        environment: APNsEnvironment
    ) async throws -> APNsSendResult
}

enum APNSError: LocalizedError {
    case invalidDeviceToken
    case invalidPayload
    case invalidCredentials
    case failedToCreateRequest
    case invalidHTTPResponse

    var errorDescription: String? {
        switch self {
        case .invalidDeviceToken:
            "Push token is empty or malformed."
        case .invalidPayload:
            "Payload is invalid JSON."
        case .invalidCredentials:
            "APNs credentials are incomplete or invalid."
        case .failedToCreateRequest:
            "Failed to create APNs request."
        case .invalidHTTPResponse:
            "APNs returned a non-HTTP response."
        }
    }
}
