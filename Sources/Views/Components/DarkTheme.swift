import SwiftUI

public struct Theme {
    public static let bgWindow = Color(red: 0.11, green: 0.12, blue: 0.14)
    public static let bgPrimary = Color(red: 0.11, green: 0.12, blue: 0.14)
    public static let bgSecondary = Color(red: 0.14, green: 0.15, blue: 0.18)
    public static let bgTertiary = Color.white.opacity(0.08)
    public static let bgCard = Color.white.opacity(0.05)

    public static let surface = Color.white.opacity(0.06)
    public static let surfaceHover = Color.white.opacity(0.10)
    public static let surfaceActive = Color.white.opacity(0.16)

    public static let textPrimary = Color.white.opacity(0.85)
    public static let textSecondary = Color.white.opacity(0.50)
    public static let textMuted = Color.white.opacity(0.35)

    public static let nsTextPrimary = NSColor(white: 1.0, alpha: 0.85)
    public static let nsTextSecondary = NSColor(white: 1.0, alpha: 0.50)

    // Design system accent colors: strictly 2 colors allowed (emerald and orange)
    public static let emerald = Color(red: 0.19, green: 0.82, blue: 0.35)
    public static let emeraldDark = Color(red: 0.12, green: 0.65, blue: 0.26)
    public static let orange = Color(red: 1.0, green: 0.55, blue: 0.10)
    public static let orangeDark = Color(red: 0.85, green: 0.42, blue: 0.05)

    // Aliases mapped to orange
    public static let amber = orange
    public static let indigo = orange
    public static let crimson = orange

    public static let separator = Color.white.opacity(0.07)
    public static let cardBorder = Color.white.opacity(0.08)
    public static let activeBorder = Color.white.opacity(0.18)
    public static let border = Color.white.opacity(0.10)
}

public struct CardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surface)
            )
    }
}

public extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

public enum ModifierStepHelper {
    public static func step(base: Double = 1.0, isDecimal: Bool = false) -> Double {
        let flags = NSEvent.modifierFlags
        if flags.contains(.control) { // 'ctrl' modifier
            return isDecimal ? 0.1 : 1.0
        } else if flags.contains(.option) { // 'alt' modifier
            return 5.0
        } else if flags.contains(.command) { // 'cmd' modifier
            return 10.0
        } else if flags.contains(.shift) && isDecimal {
            return 0.0001 // micro step
        } else {
            return base
        }
    }
}

