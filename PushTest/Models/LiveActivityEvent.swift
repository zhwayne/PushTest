import Foundation

enum LiveActivityEvent: String, CaseIterable, Identifiable, Codable {
    case start
    case update
    case end

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}
