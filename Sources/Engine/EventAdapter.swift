import Foundation
import CoreGraphics
import Cocoa

public protocol EventPosting: AnyObject {
    var isButtonDown: Bool { get }
    var lastDownButton: MouseButton? { get }
    func postClick(button: MouseButton) -> Bool
    func releaseButton(button: MouseButton) -> Bool
    func currentPointerPosition() -> CGPoint?
}

public final class NativeEventAdapter: EventPosting {
    private let lock = NSLock()
    private let eventSource: CGEventSource?

    public private(set) var isButtonDown: Bool = false
    public private(set) var lastDownButton: MouseButton? = nil

    public init() {
        // Use combined session state for accurate synthetic input distribution
        self.eventSource = CGEventSource(stateID: .combinedSessionState)
    }

    public func currentPointerPosition() -> CGPoint? {
        return CGEvent(source: nil)?.location
    }

    @discardableResult
    public func postClick(button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Guarantee pairing: if a button is somehow already down, release it first
        if isButtonDown, let heldButton = lastDownButton {
            _internalRelease(button: heldButton)
        }

        guard let pos = currentPointerPosition() else {
            return false
        }

        // 1. Create and post Mouse Down
        guard let downEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: button.downEventType,
            mouseCursorPosition: pos,
            mouseButton: button.cgMouseButton
        ) else {
            return false
        }

        downEvent.post(tap: .cghidEventTap)
        isButtonDown = true
        lastDownButton = button

        // Micro-dwell between down and up (6ms) so target apps reliably process down state
        usleep(6000)

        // 2. Create and post Mouse Up at current cursor position
        let currentPos = currentPointerPosition() ?? pos
        guard let upEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: button.upEventType,
            mouseCursorPosition: currentPos,
            mouseButton: button.cgMouseButton
        ) else {
            // Attempt emergency release
            _internalRelease(button: button)
            return false
        }

        upEvent.post(tap: .cghidEventTap)
        isButtonDown = false
        lastDownButton = nil

        return true
    }

    @discardableResult
    public func releaseButton(button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _internalRelease(button: button)
    }

    @discardableResult
    private func _internalRelease(button: MouseButton) -> Bool {
        guard isButtonDown || lastDownButton != nil else {
            return true
        }

        let targetButton = lastDownButton ?? button
        let pos = currentPointerPosition() ?? CGPoint(x: 100, y: 100)

        if let upEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: targetButton.upEventType,
            mouseCursorPosition: pos,
            mouseButton: targetButton.cgMouseButton
        ) {
            upEvent.post(tap: .cghidEventTap)
        }

        isButtonDown = false
        lastDownButton = nil
        return true
    }
}
