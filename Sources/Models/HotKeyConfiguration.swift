import Foundation
import Carbon

public struct HotKeyConfiguration: Codable, Equatable, Identifiable {
    public var id: String { displayString }
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayString: String

    public init(keyCode: UInt32 = UInt32(kVK_ANSI_A), modifiers: UInt32 = UInt32(optionKey), displayString: String = "⌥A") {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }

    public static let defaultShortcut = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: UInt32(optionKey),
        displayString: "⌥A"
    )

    public static let presets: [HotKeyConfiguration] = [
        HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey), displayString: "⌥A (Default)"),
        HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(optionKey), displayString: "⌥S"),
        HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey), displayString: "⌥C"),
        HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_X), modifiers: UInt32(optionKey), displayString: "⌥X"),
        HotKeyConfiguration(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), displayString: "⌥Space"),
        HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey), displayString: "⌃⌥A"),
        HotKeyConfiguration(keyCode: UInt32(kVK_F6), modifiers: 0, displayString: "F6"),
        HotKeyConfiguration(keyCode: UInt32(kVK_F7), modifiers: 0, displayString: "F7"),
        HotKeyConfiguration(keyCode: UInt32(kVK_F8), modifiers: 0, displayString: "F8")
    ]
}
