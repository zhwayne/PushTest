import Foundation
import XCTest
@testable import PushTest

final class APNsJWTProviderTests: XCTestCase {
    func testJWTContainsExpectedHeaderAndClaims() async throws {
        let provider = APNsJWTProvider()
        let credentials = TestFixtures.makeCredentials()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let token = try await provider.token(for: credentials, now: now)
        let segments = token.split(separator: ".")

        XCTAssertEqual(segments.count, 3)

        let header = try XCTUnwrap(decodeJSON(String(segments[0])))
        let claims = try XCTUnwrap(decodeJSON(String(segments[1])))

        XCTAssertEqual(header["alg"] as? String, "ES256")
        XCTAssertEqual(header["kid"] as? String, credentials.keyID)
        XCTAssertEqual(claims["iss"] as? String, credentials.teamID)
        XCTAssertEqual(claims["iat"] as? Int, Int(now.timeIntervalSince1970))
    }

    func testTokenCacheRefreshesAfter20Minutes() async throws {
        let provider = APNsJWTProvider(refreshInterval: 20 * 60)
        let credentials = TestFixtures.makeCredentials()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let first = try await provider.token(for: credentials, now: start)
        let cached = try await provider.token(for: credentials, now: start.addingTimeInterval(10 * 60))
        let refreshed = try await provider.token(for: credentials, now: start.addingTimeInterval(21 * 60))

        XCTAssertEqual(first, cached)
        XCTAssertNotEqual(first, refreshed)
    }

    private func decodeJSON(_ base64URL: String) -> [String: Any]? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while base64.count % 4 != 0 {
            base64 += "="
        }

        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }
}
