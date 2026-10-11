import Foundation
import Cocoa
import ApplicationServices

public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var isAccessibilityGranted: Bool = false

    private var pollTimer: Timer?

    private init() {
        self.isAccessibilityGranted = checkPermission()
        startMonitoring()
    }

    public func checkPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    public func refresh() {
        let granted = checkPermission()
        if granted != self.isAccessibilityGranted {
            DispatchQueue.main.async {
                self.isAccessibilityGranted = granted
            }
        }
    }

    public func promptForPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func startMonitoring() {
        stopMonitoring()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        stopMonitoring()
    }
}
