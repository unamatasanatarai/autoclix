import Foundation
import CoreGraphics
import Cocoa
import ApplicationServices

public protocol EventPosting: AnyObject {
    var isButtonDown: Bool { get }
    /// Posts one down/up pair. `shouldProceed` is evaluated immediately before the button-down
    /// so a stop request issued while focus/hit-testing work is in flight cancels the click.
    func postClick(button: MouseButton, focusWindow: Bool, holdDuration: TimeInterval, shouldProceed: () -> Bool) -> Bool
    func releaseButton(button: MouseButton) -> Bool
}

public final class NativeEventAdapter: EventPosting {
    /// Upper bound on any single Accessibility IPC round-trip. The default (~6s) would let a hung
    /// target app stall the engine queue, delaying stop requests by the same amount.
    private static let axMessagingTimeout: Float = 0.1
    /// Reuse an AX hit-test while the pointer stays put, to keep per-click IPC off the hot path.
    private static let hitTestCacheNanos: UInt64 = 250_000_000

    private struct HitTest {
        let position: CGPoint
        let timestamp: UInt64
        let element: AXUIElement?
        let pid: pid_t
    }

    private let lock = NSLock()
    private let eventSource: CGEventSource?
    private let systemWide: AXUIElement
    private let ownWindows: OwnWindowRegistry
    private let ownPid = ProcessInfo.processInfo.processIdentifier
    private var eventNumber: Int64 = 0
    private var lastHit: HitTest?
    private var lastFocusPid: pid_t = 0
    private var lastFocusPosition: CGPoint = .zero

    public private(set) var isButtonDown: Bool = false
    public private(set) var lastDownButton: MouseButton? = nil

    public init(ownWindows: OwnWindowRegistry = .shared) {
        // Use HID system state to match hardware-level event distribution
        self.eventSource = CGEventSource(stateID: .hidSystemState) ?? CGEventSource(stateID: .combinedSessionState)
        self.systemWide = AXUIElementCreateSystemWide()
        self.ownWindows = ownWindows
        AXUIElementSetMessagingTimeout(systemWide, NativeEventAdapter.axMessagingTimeout)
    }

    public func currentPointerPosition() -> CGPoint? {
        return CGEvent(source: nil)?.location
    }

    private func hitTest(at position: CGPoint) -> HitTest {
        let now = DispatchTime.now().uptimeNanoseconds
        if let last = lastHit,
           abs(last.position.x - position.x) < 1, abs(last.position.y - position.y) < 1,
           now &- last.timestamp < NativeEventAdapter.hitTestCacheNanos {
            return last
        }

        var element: AXUIElement?
        var pid: pid_t = 0
        if AXUIElementCopyElementAtPosition(systemWide, Float(position.x), Float(position.y), &element) == .success,
           let element = element {
            AXUIElementSetMessagingTimeout(element, NativeEventAdapter.axMessagingTimeout)
            if AXUIElementGetPid(element, &pid) != .success { pid = 0 }
        }

        let hit = HitTest(position: position, timestamp: now, element: element, pid: pid)
        lastHit = hit
        return hit
    }

    /// Checks whether the mouse cursor is hovering over AutoCliX's own window or menu bar controls.
    private func isCursorOverOwnApp(_ hit: HitTest) -> Bool {
        return ownWindows.contains(hit.position) || hit.pid == ownPid
    }

    /// Brings the window and application under the mouse pointer to the foreground,
    /// ensuring the click behaves as a genuine hardware focus-moving click across windows.
    private func ensureWindowFocus(_ hit: HitTest) {
        guard let element = hit.element, hit.pid > 0, hit.pid != ownPid else { return }

        let position = hit.position
        let frontmostPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let distSquared = (position.x - lastFocusPosition.x) * (position.x - lastFocusPosition.x) +
                          (position.y - lastFocusPosition.y) * (position.y - lastFocusPosition.y)

        // If the pointer has not moved significantly and frontmost app is already the target, skip IPC overhead
        if distSquared < 16 && frontmostPid == lastFocusPid && lastFocusPid == hit.pid {
            return
        }

        var activatedNewTarget = false
        if frontmostPid != hit.pid {
            if let app = NSRunningApplication(processIdentifier: hit.pid) {
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

        lastFocusPid = hit.pid
        lastFocusPosition = position

        if activatedNewTarget {
            // Settling dwell to allow WindowServer to activate the target window before delivering the click
            usleep(10000)
        }
    }

    @discardableResult
    public func postClick(button: MouseButton, focusWindow: Bool = true, holdDuration: TimeInterval, shouldProceed: () -> Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Guarantee pairing: if a button is somehow already down, release it first
        if isButtonDown, let heldButton = lastDownButton {
            _internalRelease(button: heldButton)
        }

        guard let pos = currentPointerPosition() else {
            return false
        }

        let hit = hitTest(at: pos)

        // Do not auto-click on AutoCliX's own window or controls
        if isCursorOverOwnApp(hit) {
            return false
        }

        // Focus and raise target window under cursor if focus mode is enabled
        if focusWindow {
            ensureWindowFocus(hit)
        }

        // Last cancellation point: once the button is down, the up event must follow.
        guard shouldProceed() else {
            return false
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

        // Micro-dwell between down and up so target apps reliably process down state
        if holdDuration > 0 {
            usleep(useconds_t(holdDuration * 1_000_000))
        }

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
