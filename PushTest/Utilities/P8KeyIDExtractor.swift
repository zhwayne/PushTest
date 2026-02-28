import Foundation

enum P8KeyIDExtractor {
    static func extract(fromFileName fileName: String) -> String? {
        let normalized = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "AuthKey_"

        guard normalized.hasPrefix(prefix),
              normalized.lowercased().hasSuffix(".p8") else {
            return nil
        }

        let start = normalized.index(normalized.startIndex, offsetBy: prefix.count)
        let end = normalized.index(normalized.endIndex, offsetBy: -3)
        guard start < end else {
            return nil
        }

        let candidate = String(normalized[start..<end])
        let isAlphanumeric = candidate.range(
            of: "^[A-Za-z0-9]+$",
            options: .regularExpression
        ) != nil

        return isAlphanumeric ? candidate : nil
    }
}
