import Foundation

struct APNsSendResult {
    var statusCode: Int
    var apnsID: String?
    var reason: String?
    var responseBody: String?
    var latencyMs: Int

    var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}
