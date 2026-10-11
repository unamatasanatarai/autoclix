import Foundation
import SwiftUI

public struct SessionStats: Equatable {
    public var clicksCount: Int
    public var startTime: Date
    public var elapsedSeconds: Double
    public var effectiveCPS: Double

    public init(clicksCount: Int = 0, startTime: Date = Date(), elapsedSeconds: Double = 0.0, effectiveCPS: Double = 0.0) {
        self.clicksCount = clicksCount
        self.startTime = startTime
        self.elapsedSeconds = elapsedSeconds
        self.effectiveCPS = effectiveCPS
    }
}

public enum EngineState: Equatable {
    case stopped
    case waiting(remainingSeconds: Double)
    case running(stats: SessionStats)
    case permissionRequired
    case error(message: String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isWaiting: Bool {
        if case .waiting = self { return true }
        return false
    }

    public var isActive: Bool {
        isRunning || isWaiting
    }

    public var statusTitle: String {
        switch self {
        case .stopped:
            return "READY"
        case .waiting:
            return "WAITING"
        case .running:
            return "RUNNING"
        case .permissionRequired:
            return "PERMISSION REQUIRED"
        case .error:
            return "ERROR"
        }
    }

    public var statusDescription: String {
        switch self {
        case .stopped:
            return "Engine stopped. Ready to start."
        case .waiting(let remaining):
            return String(format: "Starting in %.1fs...", remaining)
        case .running(let stats):
            return String(format: "%d clicks • %.1f CPS", stats.clicksCount, stats.effectiveCPS)
        case .permissionRequired:
            return "Accessibility permission needed in macOS Settings."
        case .error(let message):
            return message
        }
    }

    public var badgeColor: Color {
        switch self {
        case .stopped:
            return Color(white: 0.45)
        case .waiting, .permissionRequired, .error:
            return Color(red: 1.0, green: 0.55, blue: 0.10) // Orange
        case .running:
            return Color(red: 0.19, green: 0.82, blue: 0.35) // Emerald
        }
    }

    public var iconName: String {
        switch self {
        case .stopped:
            return "circle"
        case .waiting:
            return "hourglass"
        case .running:
            return "bolt.fill"
        case .permissionRequired:
            return "lock.shield.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
