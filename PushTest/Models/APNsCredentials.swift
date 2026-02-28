import Foundation

struct APNsCredentials: Sendable {
    var teamID: String
    var keyID: String
    var bundleID: String
    var p8PEM: String

    nonisolated var isValid: Bool {
        !teamID.trimmed.isEmpty &&
        !keyID.trimmed.isEmpty &&
        !bundleID.trimmed.isEmpty &&
        !p8PEM.trimmed.isEmpty
    }
}

private extension String {
    nonisolated var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

