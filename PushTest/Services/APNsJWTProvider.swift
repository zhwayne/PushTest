import CryptoKit
import Foundation

actor APNsJWTProvider {
    private struct CacheEntry {
        var keyID: String
        var teamID: String
        var pem: String
        var issuedAt: Date
        var token: String
    }

    private let refreshInterval: TimeInterval
    private var cacheEntry: CacheEntry?

    init(refreshInterval: TimeInterval = 20 * 60) {
        self.refreshInterval = refreshInterval
    }

    func token(for credentials: APNsCredentials, now: Date = .now) throws -> String {
        guard credentials.isValid else {
            throw APNSError.invalidCredentials
        }

        if let cacheEntry,
           cacheEntry.keyID == credentials.keyID,
           cacheEntry.teamID == credentials.teamID,
           cacheEntry.pem == credentials.p8PEM,
           now.timeIntervalSince(cacheEntry.issuedAt) < refreshInterval {
            return cacheEntry.token
        }

        let token = try makeJWT(credentials: credentials, now: now)
        cacheEntry = CacheEntry(
            keyID: credentials.keyID,
            teamID: credentials.teamID,
            pem: credentials.p8PEM,
            issuedAt: now,
            token: token
        )
        return token
    }

    private func makeJWT(credentials: APNsCredentials, now: Date) throws -> String {
        let header = [
            "alg": "ES256",
            "kid": credentials.keyID
        ]

        let claims: [String: Any] = [
            "iss": credentials.teamID,
            "iat": Int(now.timeIntervalSince1970)
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let claimsData = try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys])

        let headerPart = Base64URL.encode(headerData)
        let claimsPart = Base64URL.encode(claimsData)
        let signingInput = "\(headerPart).\(claimsPart)"

        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: credentials.p8PEM)
        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        let signaturePart = Base64URL.encode(signature.rawRepresentation)

        return "\(signingInput).\(signaturePart)"
    }
}
