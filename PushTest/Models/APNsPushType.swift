import Foundation

enum APNsPushType: String, CaseIterable, Identifiable, Codable {
    case alert
    case background
    case liveactivity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alert:
            "Alert"
        case .background:
            "Background"
        case .liveactivity:
            "Live Activity"
        }
    }

    var isLiveActivity: Bool {
        self == .liveactivity
    }

    func defaultTopic(for bundleID: String) -> String {
        if isLiveActivity {
            return "\(bundleID).push-type.liveactivity"
        }
        return bundleID
    }
}
