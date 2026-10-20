import Cocoa

/// Thread-safe snapshot of AutoCliX's visible window frames in global display coordinates
/// (top-left origin, same space as `CGEvent.location`). Refreshed on the main thread so the
/// click engine can avoid clicking its own UI without touching AppKit from a background queue.
public final class OwnWindowRegistry {
    public static let shared = OwnWindowRegistry()

    private let lock = NSLock()
    private var frames: [CGRect] = []

    public init() {}

    /// Must be called on the main thread.
    public func refresh(from windows: [NSWindow]) {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let converted = windows.filter { $0.isVisible }.map { window -> CGRect in
            let f = window.frame
            return CGRect(x: f.minX, y: primaryMaxY - f.maxY, width: f.width, height: f.height)
        }
        update(frames: converted)
    }

    public func update(frames newFrames: [CGRect]) {
        lock.lock()
        frames = newFrames
        lock.unlock()
    }

    public func contains(_ point: CGPoint) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return frames.contains { $0.contains(point) }
    }
}
