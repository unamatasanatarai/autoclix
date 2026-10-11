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
        self.cps = min(max(cps, ClickConfiguration.minCPS), ClickConfiguration.maxCPS)
        self.startDelayEnabled = startDelayEnabled
        self.startDelaySeconds = max(0.0001, startDelaySeconds)
        self.stopDurationEnabled = stopDurationEnabled
        self.stopDurationSeconds = max(0.0001, stopDurationSeconds)
        self.clickLimitEnabled = clickLimitEnabled
        self.clickLimit = max(1, clickLimit)
        self.focusWindow = focusWindow
    }

    private enum CodingKeys: String, CodingKey {
        case button, cps, startDelayEnabled, startDelaySeconds
        case stopDurationEnabled, stopDurationSeconds, clickLimitEnabled, clickLimit
        case focusWindow
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.button = try container.decodeIfPresent(MouseButton.self, forKey: .button) ?? .left
        self.cps = try container.decodeIfPresent(Double.self, forKey: .cps) ?? 8.0
        self.startDelayEnabled = try container.decodeIfPresent(Bool.self, forKey: .startDelayEnabled) ?? false
        self.startDelaySeconds = try container.decodeIfPresent(Double.self, forKey: .startDelaySeconds) ?? 3.0
        self.stopDurationEnabled = try container.decodeIfPresent(Bool.self, forKey: .stopDurationEnabled) ?? false
        self.stopDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .stopDurationSeconds) ?? 10.0
        self.clickLimitEnabled = try container.decodeIfPresent(Bool.self, forKey: .clickLimitEnabled) ?? true
        self.clickLimit = try container.decodeIfPresent(Int.self, forKey: .clickLimit) ?? 42
        self.focusWindow = try container.decodeIfPresent(Bool.self, forKey: .focusWindow) ?? true
    }

    public var intervalSeconds: Double {
        1.0 / max(cps, 0.1)
    }

    public var intervalMilliseconds: Double {
        intervalSeconds * 1000.0
    }
}
