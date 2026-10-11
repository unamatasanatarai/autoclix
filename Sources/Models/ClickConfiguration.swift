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
        clickLimit: Int = 42
    ) {
        self.button = button
        self.cps = min(max(cps, ClickConfiguration.minCPS), ClickConfiguration.maxCPS)
        self.startDelayEnabled = startDelayEnabled
        self.startDelaySeconds = max(0.0001, startDelaySeconds)
        self.stopDurationEnabled = stopDurationEnabled
        self.stopDurationSeconds = max(0.0001, stopDurationSeconds)
        self.clickLimitEnabled = clickLimitEnabled
        self.clickLimit = max(1, clickLimit)
    }

    public var intervalSeconds: Double {
        1.0 / max(cps, 0.1)
    }

    public var intervalMilliseconds: Double {
        intervalSeconds * 1000.0
    }
}
