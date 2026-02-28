import Foundation

enum TokenMasking {
    static func masked(_ token: String) -> String {
        let cleaned = token
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard cleaned.count > 4 else {
            return String(repeating: "*", count: max(cleaned.count, 1))
        }

        let suffix = cleaned.suffix(4)
        return String(repeating: "*", count: cleaned.count - 4) + suffix
    }
}
