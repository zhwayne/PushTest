import Foundation

enum JSONAutoIndentEngine {
    static let indentUnit = "  "

    struct Insertion {
        let text: String
        let cursorOffset: Int
    }

    static func insertion(for text: String, selectedRange: NSRange) -> Insertion? {
        let nsText = text as NSString
        guard selectedRange.length == 0,
              selectedRange.location <= nsText.length else {
            return nil
        }

        let cursorLocation = selectedRange.location
        let baseIndentation = leadingIndentation(in: nsText, upTo: cursorLocation)
        let previous = previousMeaningfulCharacter(in: nsText, before: cursorLocation)
        let next = nextMeaningfulCharacter(in: nsText, after: cursorLocation)
        let opensNewScope = previous == "{" || previous == "["
        let betweenMatchingPair = (previous == "{" && next == "}")
            || (previous == "[" && next == "]")

        if betweenMatchingPair {
            let insertionText = "\n\(baseIndentation)\(indentUnit)\n\(baseIndentation)"
            let cursorOffset = ("\n\(baseIndentation)\(indentUnit)" as NSString).length
            return Insertion(text: insertionText, cursorOffset: cursorOffset)
        }

        if opensNewScope {
            let insertionText = "\n\(baseIndentation)\(indentUnit)"
            let cursorOffset = (insertionText as NSString).length
            return Insertion(text: insertionText, cursorOffset: cursorOffset)
        }

        let insertionText = "\n\(baseIndentation)"
        let cursorOffset = (insertionText as NSString).length
        return Insertion(text: insertionText, cursorOffset: cursorOffset)
    }

    private static func leadingIndentation(in text: NSString, upTo location: Int) -> String {
        let lineStart = lineStartIndex(in: text, before: location)
        guard lineStart < location else {
            return ""
        }

        var index = lineStart
        var indentation = ""
        while index < location {
            let codeUnit = text.character(at: index)
            switch codeUnit {
            case 32:
                indentation.append(" ")
            case 9:
                indentation.append("\t")
            default:
                return indentation
            }
            index += 1
        }
        return indentation
    }

    private static func lineStartIndex(in text: NSString, before location: Int) -> Int {
        guard location > 0 else {
            return 0
        }

        var index = location - 1
        while index >= 0 {
            let codeUnit = text.character(at: index)
            if codeUnit == 10 || codeUnit == 13 {
                return index + 1
            }
            index -= 1
        }
        return 0
    }

    private static func previousMeaningfulCharacter(in text: NSString, before location: Int) -> Character? {
        guard location > 0 else {
            return nil
        }

        var index = location - 1
        while index >= 0 {
            let codeUnit = text.character(at: index)
            if !isWhitespaceOrNewline(codeUnit),
               let scalar = UnicodeScalar(codeUnit) {
                return Character(scalar)
            }
            index -= 1
        }
        return nil
    }

    private static func nextMeaningfulCharacter(in text: NSString, after location: Int) -> Character? {
        guard location < text.length else {
            return nil
        }

        var index = location
        while index < text.length {
            let codeUnit = text.character(at: index)
            if !isWhitespaceOrNewline(codeUnit),
               let scalar = UnicodeScalar(codeUnit) {
                return Character(scalar)
            }
            index += 1
        }
        return nil
    }

    private static func isWhitespaceOrNewline(_ codeUnit: unichar) -> Bool {
        guard let scalar = UnicodeScalar(codeUnit) else {
            return false
        }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
