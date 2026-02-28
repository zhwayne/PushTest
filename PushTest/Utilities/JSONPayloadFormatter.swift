import Foundation

enum JSONPayloadFormatter {
    private static let indentUnit = "  "

    enum FormatterError: LocalizedError {
        case invalidUTF8
        case invalidJSON
        case unableToEncode

        var errorDescription: String? {
            switch self {
            case .invalidUTF8:
                "Payload is not valid UTF-8."
            case .invalidJSON:
                "Payload is not valid JSON."
            case .unableToEncode:
                "Unable to encode formatted JSON."
            }
        }
    }

    static func format(_ text: String) throws -> String {
        guard let inputData = text.data(using: .utf8) else {
            throw FormatterError.invalidUTF8
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: inputData, options: [])
        } catch {
            throw FormatterError.invalidJSON
        }

        let outputData: Data
        do {
            outputData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            )
        } catch {
            throw FormatterError.unableToEncode
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw FormatterError.unableToEncode
        }

        return normalizeIndentation(output)
    }

    private static func normalizeIndentation(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let leadingSpaces = line.prefix { $0 == " " }.count
                guard leadingSpaces > 0 else {
                    return String(line)
                }

                let indentLevel = leadingSpaces / 2
                let remainingSpaces = leadingSpaces % 2
                let body = line.dropFirst(leadingSpaces)

                return String(repeating: indentUnit, count: indentLevel)
                + String(repeating: " ", count: remainingSpaces)
                + String(body)
            }
            .joined(separator: "\n")
    }
}
