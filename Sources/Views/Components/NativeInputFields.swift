import SwiftUI
import AppKit

/// A native AppKit text field restricted to digits [0-9] only.
/// Supports real-time clamping (e.g. min 1, max 900 for CPS),
/// instant rejection of non-digits, and on-the-fly engine synchronization.
final class UnfocusedTextField: NSTextField {
    override var canBecomeKeyView: Bool { false }
}

public struct NativeDigitsField: NSViewRepresentable {
    @Binding public var text: String
    public var minValue: Int = 1
    public var maxValue: Int = 900
    public var fontSize: CGFloat = 12
    public var fontWeight: NSFont.Weight = .bold
    public var alignment: NSTextAlignment = .center
    public var textColor: NSColor = Theme.nsTextPrimary
    public var onChange: ((Int) -> Void)?

    public init(
        text: Binding<String>,
        minValue: Int = 1,
        maxValue: Int = 900,
        fontSize: CGFloat = 12,
        fontWeight: NSFont.Weight = .bold,
        alignment: NSTextAlignment = .center,
        textColor: NSColor = Theme.nsTextPrimary,
        onChange: ((Int) -> Void)? = nil
    ) {
        self._text = text
        self.minValue = minValue
        self.maxValue = maxValue
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.alignment = alignment
        self.textColor = textColor
        self.onChange = onChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSTextField {
        let tf = UnfocusedTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.textColor = textColor
        tf.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: fontWeight)
        tf.alignment = alignment
        tf.focusRingType = .none
        tf.maximumNumberOfLines = 1
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true
        tf.delegate = context.coordinator
        tf.stringValue = text
        return tf
    }

    public func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.textColor != textColor {
            nsView.textColor = textColor
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
            if let editor = nsView.currentEditor() {
                let loc = min(editor.selectedRange.location, text.utf16.count)
                editor.selectedRange = NSRange(location: loc, length: 0)
            }
        }
    }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeDigitsField

        init(_ parent: NativeDigitsField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let raw = tf.stringValue
            let digits = raw.filter { $0.isNumber }

            var validated = digits
            if let num = Int(digits) {
                if num < parent.minValue {
                    validated = "\(parent.minValue)"
                } else if num > parent.maxValue {
                    validated = "\(parent.maxValue)"
                } else {
                    validated = "\(num)"
                }
            } else if digits.isEmpty {
                validated = ""
            }

            if tf.stringValue != validated {
                tf.stringValue = validated
                if let editor = tf.currentEditor() {
                    let loc = min(editor.selectedRange.location, validated.utf16.count)
                    editor.selectedRange = NSRange(location: loc, length: 0)
                }
            }

            parent.text = validated
            if let num = Int(validated) {
                parent.onChange?(num)
            } else if validated.isEmpty {
                parent.onChange?(parent.minValue)
            }
        }

        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}

/// A native AppKit text field supporting decimals (number.number) with minimum 0.1 ms (0.0001s).
/// Rejects non-numeric characters on the fly, allows typing decimals seamlessly,
/// and synchronizes changes immediately with the engine.
public struct NativeDecimalField: NSViewRepresentable {
    @Binding public var text: String
    public var minValue: Double = 0.0001
    public var maxValue: Double = 86400.0
    public var fontSize: CGFloat = 10
    public var fontWeight: NSFont.Weight = .semibold
    public var alignment: NSTextAlignment = .center
    public var textColor: NSColor = Theme.nsTextPrimary
    public var onChange: ((Double) -> Void)?

    public init(
        text: Binding<String>,
        minValue: Double = 0.0001,
        maxValue: Double = 86400.0,
        fontSize: CGFloat = 10,
        fontWeight: NSFont.Weight = .semibold,
        alignment: NSTextAlignment = .center,
        textColor: NSColor = Theme.nsTextPrimary,
        onChange: ((Double) -> Void)? = nil
    ) {
        self._text = text
        self.minValue = minValue
        self.maxValue = maxValue
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.alignment = alignment
        self.textColor = textColor
        self.onChange = onChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSTextField {
        let tf = UnfocusedTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.textColor = textColor
        tf.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: fontWeight)
        tf.alignment = alignment
        tf.focusRingType = .none
        tf.maximumNumberOfLines = 1
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true
        tf.delegate = context.coordinator
        tf.stringValue = text
        return tf
    }

    public func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.textColor != textColor {
            nsView.textColor = textColor
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
            if let editor = nsView.currentEditor() {
                let loc = min(editor.selectedRange.location, text.utf16.count)
                editor.selectedRange = NSRange(location: loc, length: 0)
            }
        }
    }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeDecimalField

        init(_ parent: NativeDecimalField) {
            self.parent = parent
        }

        private func filterDecimal(_ raw: String) -> String {
            var hasDot = false
            var result = ""
            for ch in raw.replacingOccurrences(of: ",", with: ".") {
                if ch.isNumber {
                    result.append(ch)
                } else if ch == "." && !hasDot {
                    hasDot = true
                    result.append(ch)
                }
            }
            return result
        }

        private func formatNumberString(_ val: Double) -> String {
            if val.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(val))"
            } else {
                let str = String(format: "%.4f", val)
                var trimmed = str
                while trimmed.hasSuffix("0") { trimmed.removeLast() }
                if trimmed.hasSuffix(".") { trimmed.removeLast() }
                return trimmed
            }
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let raw = tf.stringValue
            let filtered = filterDecimal(raw)
            var validated = filtered

            if let val = Double(filtered), !filtered.hasSuffix(".") {
                if val > parent.maxValue {
                    validated = formatNumberString(parent.maxValue)
                }
            }

            if tf.stringValue != validated {
                tf.stringValue = validated
                if let editor = tf.currentEditor() {
                    let loc = min(editor.selectedRange.location, validated.utf16.count)
                    editor.selectedRange = NSRange(location: loc, length: 0)
                }
            }

            parent.text = validated

            if let val = Double(validated), !validated.hasSuffix(".") {
                let clamped = max(parent.minValue, min(parent.maxValue, val))
                parent.onChange?(clamped)
            }
        }

        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
