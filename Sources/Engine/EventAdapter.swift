import Foundation
import CoreGraphics
import Cocoa
import ApplicationServices

public protocol EventPosting: AnyObject {
    var isButtonDown: Bool { get }
    var lastDownButton: MouseButton? { get }
    func postClick(button: MouseButton, focusWindow: Bool) -> Bool
    func releaseButton(button: MouseButton) -> Bool
    func currentPointerPosition() -> CGPoint?
}

public final class NativeEventAdapter: EventPosting {
    private let lock = NSLock()
    private let eventSource: CGEventSource?
    private var eventNumber: Int64 = 0
    private var lastFocusPid: pid_t = 0
    private var lastFocusPosition: CGPoint = .zero

    public private(set) var isButtonDown: Bool = false
    public private(set) var lastDownButton: MouseButton? = nil

    public init() {
        // Use HID system state to match hardware-level event distribution
        self.eventSource = CGEventSource(stateID: .hidSystemState) ?? CGEventSource(stateID: .combinedSessionState)
    }

    public func currentPointerPosition() -> CGPoint? {
        return CGEvent(source: nil)?.location
    }

    /// Brings the window and application under the mouse pointer to the foreground,
    /// ensuring the click behaves as a genuine hardware focus-moving click across windows.
    private func ensureWindowFocus(at position: CGPoint) {
        let frontmostPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let distSquared = (position.x - lastFocusPosition.x) * (position.x - lastFocusPosition.x) +
                          (position.y - lastFocusPosition.y) * (position.y - lastFocusPosition.y)

        // If the pointer has not moved significantly and frontmost app is already the target, skip IPC overhead
        if distSquared < 16 && frontmostPid == lastFocusPid && lastFocusPid != 0 {
            return
        }

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(position.x), Float(position.y), &element) == .success,
              let element = element else {
            return
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0 else { return }

        // Do not activate our own menu bar utility
        if pid == ProcessInfo.processInfo.processIdentifier { return }

        var activatedNewTarget = false
        if frontmostPid != pid {
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: .activateIgnoringOtherApps)
                activatedNewTarget = true
            }
        }

        // Raise the target window to the front and set it as the main window
        var winRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &winRef) == .success,
           let winRef = winRef {
            let win = winRef as! AXUIElement
            AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        } else {
            AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        }

        lastFocusPid = pid
        lastFocusPosition = position

        if activatedNewTarget {
            // Settling dwell to allow WindowServer to activate the target window before delivering the click
            usleep(10000)
        }
    }

    @discardableResult
    public func postClick(button: MouseButton, focusWindow: Bool = true) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Guarantee pairing: if a button is somehow already down, release it first
        if isButtonDown, let heldButton = lastDownButton {
            _internalRelease(button: heldButton)
        }

        guard let pos = currentPointerPosition() else {
            return false
        }

        // Focus and raise target window under cursor if focus mode is enabled
        if focusWindow {
            ensureWindowFocus(at: pos)
        }

        eventNumber += 1

        // 1. Create and post Mouse Down with real click properties
        guard let downEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: button.downEventType,
            mouseCursorPosition: pos,
            mouseButton: button.cgMouseButton
        ) else {
            return false
        }

        downEvent.setIntegerValueField(.mouseEventClickState, value: 1)
        downEvent.setIntegerValueField(.mouseEventNumber, value: eventNumber)

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

        upEvent.setIntegerValueField(.mouseEventClickState, value: 1)
        upEvent.setIntegerValueField(.mouseEventNumber, value: eventNumber)

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
            upEvent.setIntegerValueField(.mouseEventClickState, value: 1)
            upEvent.setIntegerValueField(.mouseEventNumber, value: eventNumber)
            upEvent.post(tap: .cghidEventTap)
        }

        isButtonDown = false
        lastDownButton = nil
        return true
    }
}
