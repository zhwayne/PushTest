import AppKit
import Highlightr

final class JSONSyntaxHighlighter {
    static let shared = JSONSyntaxHighlighter()

    private let maximumHighlightLength = 200_000
    private let highlightr: Highlightr?

    private init() {
        let engine = Highlightr()
        engine?.setTheme(to: "xcode")
        highlightr = engine
    }

    var maximumLength: Int {
        maximumHighlightLength
    }

    func highlight(text: String) -> NSAttributedString? {
        guard text.utf16.count <= maximumHighlightLength,
              let highlightr else {
            return nil
        }

        return highlightr.highlight(text, as: "json")
    }

    func attributedString(
        for text: String,
        baseAttributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        highlight(text: text) ?? NSAttributedString(string: text, attributes: baseAttributes)
    }
}
