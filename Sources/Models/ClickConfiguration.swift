import Foundation

public struct ClickConfiguration: Codable, Equatable {
    public var button: MouseButton
    public var cps: Double
    public var startDelayEnabled: Bool
    public var startDelaySeconds: Double
    public var stopDurationEnabled: Bool
    public var stopDurationSeconds: Double
    public var clickLimitEnabled: Bool
    public var clickLimit: Int
    public var focusWindow: Bool

    public static let minCPS: Double = 1.0
    public static let maxCPS: Double = 900.0
    public static let defaultCPS: Double = 8.0
    public static let defaultClickLimit: Int = 42
    public static let maxClickLimit: Int = 10_000_000
    public static let minSeconds: Double = 0.0001 // 0.1 ms
    public static let maxStartDelaySeconds: Double = 3600.0
    public static let maxStopDurationSeconds: Double = 86400.0

    public init(
        button: MouseButton = .left,
        cps: Double = 8.0,
        startDelayEnabled: Bool = false,
        startDelaySeconds: Double = 3.0,
        stopDurationEnabled: Bool = false,
        stopDurationSeconds: Double = 10.0,
        clickLimitEnabled: Bool = true,
        clickLimit: Int = 42,
        focusWindow: Bool = true
    ) {
        self.button = button
        self.cps = ClickConfiguration.clamp(cps, ClickConfiguration.minCPS, ClickConfiguration.maxCPS, fallback: ClickConfiguration.defaultCPS)
        self.startDelayEnabled = startDelayEnabled
        self.startDelaySeconds = ClickConfiguration.clamp(startDelaySeconds, ClickConfiguration.minSeconds, ClickConfiguration.maxStartDelaySeconds, fallback: 3.0)
        self.stopDurationEnabled = stopDurationEnabled
        self.stopDurationSeconds = ClickConfiguration.clamp(stopDurationSeconds, ClickConfiguration.minSeconds, ClickConfiguration.maxStopDurationSeconds, fallback: 10.0)
        self.clickLimitEnabled = clickLimitEnabled
        self.clickLimit = min(max(1, clickLimit), ClickConfiguration.maxClickLimit)
        self.focusWindow = focusWindow
    }

    private enum CodingKeys: String, CodingKey {
        case button, cps, startDelayEnabled, startDelaySeconds
        case stopDurationEnabled, stopDurationSeconds, clickLimitEnabled, clickLimit
        case focusWindow
    }

    // Routed through the clamping initializer so persisted values can never violate the invariants.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            button: try container.decodeIfPresent(MouseButton.self, forKey: .button) ?? .left,
            cps: try container.decodeIfPresent(Double.self, forKey: .cps) ?? 8.0,
            startDelayEnabled: try container.decodeIfPresent(Bool.self, forKey: .startDelayEnabled) ?? false,
            startDelaySeconds: try container.decodeIfPresent(Double.self, forKey: .startDelaySeconds) ?? 3.0,
            stopDurationEnabled: try container.decodeIfPresent(Bool.self, forKey: .stopDurationEnabled) ?? false,
            stopDurationSeconds: try container.decodeIfPresent(Double.self, forKey: .stopDurationSeconds) ?? 10.0,
            clickLimitEnabled: try container.decodeIfPresent(Bool.self, forKey: .clickLimitEnabled) ?? true,
            clickLimit: try container.decodeIfPresent(Int.self, forKey: .clickLimit) ?? 42,
            focusWindow: try container.decodeIfPresent(Bool.self, forKey: .focusWindow) ?? true
        )
    }

    /// Returns a copy with every field clamped to its valid range.
    /// Needed because views mutate fields directly, bypassing `init`.
    public func sanitized() -> ClickConfiguration {
        ClickConfiguration(
            button: button,
            cps: cps,
            startDelayEnabled: startDelayEnabled,
            startDelaySeconds: startDelaySeconds,
            stopDurationEnabled: stopDurationEnabled,
            stopDurationSeconds: stopDurationSeconds,
            clickLimitEnabled: clickLimitEnabled,
            clickLimit: clickLimit,
            focusWindow: focusWindow
        )
    }

    public var intervalSeconds: Double {
        1.0 / max(cps, 0.1)
    }

    public var intervalMilliseconds: Double {
        intervalSeconds * 1000.0
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, lower), upper)
    }
}
