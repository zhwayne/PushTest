import Foundation

enum APNsEnvironment: String, CaseIterable, Identifiable, Codable {
    case sandbox
    case production

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sandbox:
            "Sandbox"
        case .production:
            "Production"
        }
    }

    var host: String {
        switch self {
        case .sandbox:
            "api.sandbox.push.apple.com"
        case .production:
            "api.push.apple.com"
        }
    }

    var baseURL: URL {
        URL(string: "https://\(host)")!
    }
}
