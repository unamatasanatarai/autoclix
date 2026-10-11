import Foundation
import SwiftUI
import Combine

public final class ClickEngine: ObservableObject {
    public static let shared = ClickEngine()

    @Published public internal(set) var state: EngineState = .stopped
    @Published public var config: ClickConfiguration {
        didSet {
            PreferencesManager.shared.saveClickConfiguration(config)
        }
    }

    private let adapter: EventPosting
    private let engineQueue = DispatchQueue(label: "com.autoclix.engine", qos: .userInteractive)

    private var currentSessionId: UUID?
    private var clickTimer: DispatchSourceTimer?
    private var countdownTimer: DispatchSourceTimer?
    private var statsTimer: DispatchSourceTimer?

    private var sessionStartTime: Date?
    private var totalClicksCount: Int = 0
    private var isClickInProgress: Bool = false
    private var lastClickMachTime: UInt64 = 0

    public init(adapter: EventPosting = NativeEventAdapter()) {
        self.adapter = adapter
        self.config = PreferencesManager.shared.loadClickConfiguration()
    }

    // MARK: - Public Control API

    public func toggle() {
        if state.isActive {
            stop()
        } else {
            start()
        }
    }

    public func start() {
        // Verify Accessibility permission
        guard PermissionManager.shared.checkPermission() else {
            DispatchQueue.main.async {
                self.state = .permissionRequired
            }
            PermissionManager.shared.promptForPermission()
            return
        }

        engineQueue.async { [weak self] in
            guard let self = self else { return }

            // Stop any lingering session first
            self._internalStop()

            let sessionId = UUID()
            self.currentSessionId = sessionId
            self.totalClicksCount = 0

            if self.config.startDelayEnabled && self.config.startDelaySeconds > 0 {
                self._startDelayCountdown(sessionId: sessionId, totalSeconds: self.config.startDelaySeconds)
            } else {
                self._beginRunningSession(sessionId: sessionId)
            }
        }
    }

    public func stop() {
        engineQueue.async { [weak self] in
            self?._internalStop()
        }
    }

    // MARK: - Internal Engine Logic (Runs on engineQueue)

    private func _startDelayCountdown(sessionId: UUID, totalSeconds: Double) {
        var remaining = totalSeconds

        DispatchQueue.main.async {
            self.state = .waiting(remainingSeconds: remaining)
        }

        let timer = DispatchSource.makeTimerSource(queue: engineQueue)
        self.countdownTimer = timer

        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.currentSessionId == sessionId else {
                timer.cancel()
                return
            }

            remaining -= 0.1
            if remaining <= 0.05 {
                timer.cancel()
                self.countdownTimer = nil
                self._beginRunningSession(sessionId: sessionId)
            } else {
                let currentRemaining = remaining
                DispatchQueue.main.async {
                    if self.currentSessionId == sessionId {
                        self.state = .waiting(remainingSeconds: currentRemaining)
                    }
                }
            }
        }
        timer.resume()
    }

    private func _beginRunningSession(sessionId: UUID) {
        guard self.currentSessionId == sessionId else { return }

        let now = Date()
        self.sessionStartTime = now
        self.totalClicksCount = 0
        self.lastClickMachTime = mach_absolute_time()

        let initialStats = SessionStats(
            clicksCount: 0,
            startTime: now,
            elapsedSeconds: 0,
            effectiveCPS: self.config.cps
        )

        DispatchQueue.main.async {
            if self.currentSessionId == sessionId {
                self.state = .running(stats: initialStats)
            }
        }

        // Setup high-precision click timer
        let intervalSeconds = self.config.intervalSeconds
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: engineQueue)
        self.clickTimer = timer

        // Monotonic cadence scheduling
        let intervalMicros = max(100, Int(intervalSeconds * 1_000_000))
        let leewayMicros = max(20, min(200, intervalMicros / 5))
        timer.schedule(
            deadline: .now(),
            repeating: DispatchTimeInterval.microseconds(intervalMicros),
            leeway: DispatchTimeInterval.microseconds(leewayMicros)
        )

        timer.setEventHandler { [weak self] in
            guard let self = self, self.currentSessionId == sessionId else { return }

            // Guard against overlapping click execution
            guard !self.isClickInProgress else { return }

            // Avoid catch-up bursts: check minimum time elapsed since last click
            let currentMach = mach_absolute_time()
            let minIntervalNs = UInt64(intervalSeconds * 0.70 * 1_000_000_000)
            var timebase = mach_timebase_info()
            mach_timebase_info(&timebase)
            let elapsedNs = (currentMach - self.lastClickMachTime) * UInt64(timebase.numer) / UInt64(timebase.denom)

            if self.totalClicksCount > 0 && elapsedNs < minIntervalNs {
                // System was stalled or ticking too fast; skip missed tick to prevent burst
                return
            }

            self.isClickInProgress = true
            self.lastClickMachTime = currentMach

            let success = self.adapter.postClick(button: self.config.button)
            self.isClickInProgress = false

            if success {
                self.totalClicksCount += 1
            }

            // Check click limit limit
            if self.config.clickLimitEnabled && self.totalClicksCount >= self.config.clickLimit {
                self._internalStop()
                return
            }

            // Check stop duration limit
            if self.config.stopDurationEnabled, let start = self.sessionStartTime {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= self.config.stopDurationSeconds {
                    self._internalStop()
                    return
                }
            }
        }
        timer.resume()

        // Setup HUD stats refresh timer (every 0.2s)
        let stats = DispatchSource.makeTimerSource(queue: engineQueue)
        self.statsTimer = stats
        stats.schedule(deadline: .now() + 0.2, repeating: 0.2)
        stats.setEventHandler { [weak self] in
            guard let self = self, self.currentSessionId == sessionId, let start = self.sessionStartTime else { return }

            let elapsed = Date().timeIntervalSince(start)
            let clicks = self.totalClicksCount
            let effectiveCPS = elapsed > 0.05 ? Double(clicks) / elapsed : self.config.cps

            let updatedStats = SessionStats(
                clicksCount: clicks,
                startTime: start,
                elapsedSeconds: elapsed,
                effectiveCPS: effectiveCPS
            )

            DispatchQueue.main.async {
                if self.currentSessionId == sessionId {
                    self.state = .running(stats: updatedStats)
                }
            }
        }
        stats.resume()
    }

    private func _internalStop() {
        self.currentSessionId = nil

        self.countdownTimer?.cancel()
        self.countdownTimer = nil

        self.clickTimer?.cancel()
        self.clickTimer = nil

        self.statsTimer?.cancel()
        self.statsTimer = nil

        self.isClickInProgress = false

        // Always resolve any unresolved button down state
        if self.adapter.isButtonDown {
            _ = self.adapter.releaseButton(button: self.config.button)
        }

        DispatchQueue.main.async {
            self.state = .stopped
        }
    }

    deinit {
        _internalStop()
    }
}
