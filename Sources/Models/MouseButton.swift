import Foundation
import CoreGraphics

public enum MouseButton: String, CaseIterable, Identifiable, Codable {
    case left = "left"
    case middle = "middle"
    case right = "right"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .middle:
            return "Middle"
        case .right:
            return "Right"
        }
    }

    public var subtitle: String {
        switch self {
        case .left:
            return "Primary Click"
        case .right:
            return "Secondary Click"
        case .middle:
            return "Center / Scroll Wheel"
        }
    }

    public var cgMouseButton: CGMouseButton {
        switch self {
        case .left:
            return .left
        case .right:
            return .right
        case .middle:
            return .center
        }
    }

    public var downEventType: CGEventType {
        switch self {
        case .left:
            return .leftMouseDown
        case .right:
            return .rightMouseDown
        case .middle:
            return .otherMouseDown
        }
    }

    public var upEventType: CGEventType {
        switch self {
        case .left:
            return .leftMouseUp
        case .right:
            return .rightMouseUp
        case .middle:
            return .otherMouseUp
        }
    }

    public var iconName: String {
        switch self {
        case .left:
            return "hand.point.left.fill"
        case .right:
            return "hand.point.right.fill"
        case .middle:
            return "circle.circle.fill"
        }
    }
}
