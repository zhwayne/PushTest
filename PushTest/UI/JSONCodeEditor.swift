import AppKit
import SwiftUI

struct JSONCodeEditor: NSViewRepresentable {
    @Binding var text: String

    let syntaxHighlighter: JSONSyntaxHighlighter
    var onTextChange: ((String) -> Void)?
    var onEditingEnded: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.contentView.copiesOnScroll = false
        scrollView.contentView.drawsBackground = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainer?.lineFragmentPadding = 2
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.font = Coordinator.editorFont
        textView.textColor = .labelColor
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.wantsLayer = true
        textView.layer?.masksToBounds = true

        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDataDetectionEnabled = false

        context.coordinator.textView = textView
        context.coordinator.apply(text: text, preserveSelection: false)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = context.coordinator.textView else {
            return
        }

        if textView.string != text {
            context.coordinator.apply(text: text, preserveSelection: true)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        static let editorFont = NSFont.monospacedSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .regular
        )

        var parent: JSONCodeEditor
        weak var textView: NSTextView?

        private var isApplyingProgrammatically = false

        init(parent: JSONCodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammatically,
                  let textView else {
                return
            }

            let latestText = textView.string
            parent.text = latestText
            parent.onTextChange?(latestText)
            apply(text: latestText, preserveSelection: true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEditingEnded?()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)),
                  textView.selectedRanges.count == 1 else {
                return false
            }

            let selectedRange = textView.selectedRange()
            guard let insertion = JSONAutoIndentEngine.insertion(
                for: textView.string,
                selectedRange: selectedRange
            ) else {
                return false
            }

            guard textView.shouldChangeText(in: selectedRange, replacementString: insertion.text) else {
                return true
            }

            textView.textStorage?.replaceCharacters(in: selectedRange, with: insertion.text)
            textView.didChangeText()
            textView.setSelectedRange(
                NSRange(location: selectedRange.location + insertion.cursorOffset, length: 0)
            )
            return true
        }

        func apply(text: String, preserveSelection: Bool) {
            guard let textView else {
                return
            }

            let selectionValues: [NSValue] = preserveSelection ? textView.selectedRanges : []
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: Self.editorFont,
                .foregroundColor: NSColor.labelColor
            ]
            let highlighted = parent.syntaxHighlighter.attributedString(
                for: text,
                baseAttributes: baseAttributes
            )

            isApplyingProgrammatically = true
            textView.textStorage?.setAttributedString(highlighted)
            textView.typingAttributes = baseAttributes
            isApplyingProgrammatically = false

            guard preserveSelection else {
                let end = highlighted.length
                textView.setSelectedRange(NSRange(location: end, length: 0))
                return
            }

            textView.selectedRanges = selectionValues.map { selectionValue in
                let range = selectionValue.rangeValue
                return NSValue(range: clamped(range: range, maxLength: highlighted.length))
            }
        }

        private func clamped(range: NSRange, maxLength: Int) -> NSRange {
            let start = min(max(0, range.location), maxLength)
            let end = min(max(start, range.location + range.length), maxLength)
            return NSRange(location: start, length: end - start)
        }
    }
}
