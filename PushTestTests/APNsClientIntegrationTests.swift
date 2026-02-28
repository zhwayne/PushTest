import Foundation
import XCTest
@testable import PushTest

final class APNsClientIntegrationTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testSendSuccessResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let client = APNsClient(session: session)
        let credentials = TestFixtures.makeCredentials(bundleID: "com.example.live")
        let draft = TestFixtures.makeDraft(event: .start, token: "abcd1234")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.sandbox.push.apple.com/3/device/abcd1234")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apns-push-type"), "liveactivity")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apns-topic"), "com.example.live.push-type.liveactivity")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "authorization"))

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["apns-id": "apns-success-id"]
            )!
            return (response, Data())
        }

        let result = try await client.send(draft: draft, credentials: credentials, environment: .sandbox)

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.apnsID, "apns-success-id")
    }

    func testSendFailureResponseParsesReason() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let client = APNsClient(session: session)
        let credentials = TestFixtures.makeCredentials(bundleID: "com.example.live")
        let draft = TestFixtures.makeDraft(event: .update, token: "efgh5678")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 400,
                httpVersion: nil,
                headerFields: ["apns-id": "apns-fail-id"]
            )!
            let body = "{\"reason\":\"BadDeviceToken\"}".data(using: .utf8)!
            return (response, body)
        }

        let result = try await client.send(draft: draft, credentials: credentials, environment: .sandbox)

        XCTAssertEqual(result.statusCode, 400)
        XCTAssertEqual(result.reason, "BadDeviceToken")
        XCTAssertEqual(result.apnsID, "apns-fail-id")
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
