import Foundation
import SwiftUI
import Combine
import ApplicationServices

/// Threading model:
/// - `state` and `config` are owned by the main thread.
/// - Timers, counters and `sessionConfig` are owned by `engineQueue`.
/// - `activeSessionId` is the single source of truth for "is a session live" and is guarded by
///   `sessionLock`, so start/stop/toggle take effect synchronously from any thread and an
///   in-flight click can observe a stop request before posting its button-down.
public final class ClickEngine: ObservableObject {
    public static let shared = ClickEngine()

    /// Longest button hold between down and up. Scaled down at high CPS so the hold never
    /// dominates the interval (6ms alone would cap throughput at ~166 CPS).
    static let maxHoldDuration: TimeInterval = 0.006

    @Published public internal(set) var state: EngineState = .stopped
    @Published public var config: ClickConfiguration {
        didSet {
            let sanitized = config.sanitized()
            if sanitized != config {
                config = sanitized
            }
            preferences?.saveClickConfiguration(sanitized)
            engineQueue.async { [weak self] in
                self?._applyConfig(sanitized)
            }
        }
    }

    private let adapter: EventPosting
    private let preferences: PreferencesManager?
    private let hasPermission: () -> Bool
    private let requestPermission: () -> Void
    private let engineQueue = DispatchQueue(label: "com.autoclix.engine", qos: .userInteractive)

    private let sessionLock = NSLock()
    private var activeSessionId: UUID? // guarded by sessionLock

    // MARK: engineQueue-owned state
    private var sessionConfig: ClickConfiguration
    private var clickTimer: DispatchSourceTimer?
    private var countdownTimer: DispatchSourceTimer?
    private var statsTimer: DispatchSourceTimer?
    private var scheduledInterval: Double = 0
    private var sessionStartDate = Date()
    private var sessionStartUptime: UInt64 = 0
    private var lastClickUptime: UInt64 = 0
    private var totalClicksCount: Int = 0

    public init(
        adapter: EventPosting = NativeEventAdapter(),
        preferences: PreferencesManager? = .shared,
        hasPermission: @escaping () -> Bool = { AXIsProcessTrusted() },
        requestPermission: @escaping () -> Void = { PermissionManager.shared.promptForPermission() }
    ) {
        let initialConfig = preferences?.loadClickConfiguration() ?? ClickConfiguration()
        self.adapter = adapter
        self.preferences = preferences
        self.hasPermission = hasPermission
        self.requestPermission = requestPermission
        self.config = initialConfig
        self.sessionConfig = initialConfig
    }

    // MARK: - Public Control API

    /// True from the moment `start()` returns until `stop()` is called or a limit ends the session.
    /// Unlike `state`, this never lags behind a main-queue hop.
    public var isSessionActive: Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return activeSessionId != nil
    }

    public func toggle() {
        if isSessionActive {
            stop()
        } else {
            start()
        }
    }

    public func start() {
        guard hasPermission() else {
            setStateOnMain(.permissionRequired)
            DispatchQueue.main.async { self.requestPermission() }
            return
        }

        let sessionId = UUID()
        sessionLock.lock()
        activeSessionId = sessionId
        sessionLock.unlock()

        let snapshot = currentConfigSnapshot()
        engineQueue.async { [weak self] in
            self?._beginSession(sessionId, config: snapshot)
        }
    }

    public func stop() {
        clearSession()
        setStateOnMain(.stopped)
        engineQueue.async { [weak self] in
            self?._teardown()
        }
    }

    /// Stops and blocks until timers are cancelled and any held button is released.
    /// Use at app termination, where an async stop would never run.
    public func stopAndWait() {
        clearSession()
        engineQueue.sync {
            _teardown()
        }
        setStateOnMain(.stopped)
    }

    /// Reacts to Accessibility permission being granted or revoked while the app runs.
    public func permissionChanged(granted: Bool) {
        if !granted {
            if isSessionActive {
                stop()
            }
            setStateOnMain(.permissionRequired)
        } else if case .permissionRequired = state {
            setStateOnMain(.stopped)
        }
    }

    // MARK: - Session bookkeeping (any thread)

    private func isCurrent(_ sessionId: UUID) -> Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return activeSessionId == sessionId
    }

    private func clearSession() {
        sessionLock.lock()
        activeSessionId = nil
        sessionLock.unlock()
    }

    /// Clears the session only if it is still the given one, so a session that ends itself
    /// cannot clobber a newer session started in the meantime.
    private func clearSession(ifCurrent sessionId: UUID) -> Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard activeSessionId == sessionId else { return false }
        activeSessionId = nil
        return true
    }

    private func currentConfigSnapshot() -> ClickConfiguration {
        if Thread.isMainThread {
            return config
        }
        return DispatchQueue.main.sync { config }
    }

    private func setStateOnMain(_ newState: EngineState) {
        if Thread.isMainThread {
            state = newState
        } else {
            DispatchQueue.main.async { self.state = newState }
        }
    }

    /// Publishes session progress, dropping it if the session has ended by the time main runs it.
    private func _publish(_ newState: EngineState, for sessionId: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isCurrent(sessionId) else { return }
            self.state = newState
        }
    }

    // MARK: - Internal Engine Logic (Runs on engineQueue)

    private func _applyConfig(_ newConfig: ClickConfiguration) {
        sessionConfig = newConfig
        if let timer = clickTimer, newConfig.intervalSeconds != scheduledInterval {
            _scheduleClickTimer(timer, interval: newConfig.intervalSeconds)
        }
    }

    private func _beginSession(_ sessionId: UUID, config: ClickConfiguration) {
        _teardown()
        guard isCurrent(sessionId) else { return }

        sessionConfig = config
        totalClicksCount = 0

        if config.startDelayEnabled && config.startDelaySeconds > 0 {
            _startDelayCountdown(sessionId: sessionId, totalSeconds: config.startDelaySeconds)
        } else {
            _beginRunningSession(sessionId: sessionId)
        }
    }

    private func _startDelayCountdown(sessionId: UUID, totalSeconds: Double) {
        let tick: UInt64 = 100_000_000
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(totalSeconds * 1_000_000_000)

        _publish(.waiting(remainingSeconds: totalSeconds), for: sessionId)

        let timer = DispatchSource.makeTimerSource(queue: engineQueue)
        self.countdownTimer = timer

        let firstFire = min(DispatchTime.now().uptimeNanoseconds + tick, deadline)
        timer.schedule(deadline: DispatchTime(uptimeNanoseconds: firstFire), repeating: .nanoseconds(Int(tick)))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isCurrent(sessionId) else {
                timer.cancel()
                return
            }

            let now = DispatchTime.now().uptimeNanoseconds
            if now >= deadline {
                timer.cancel()
                self.countdownTimer = nil
                self._beginRunningSession(sessionId: sessionId)
                return
            }

            self._publish(.waiting(remainingSeconds: Double(deadline - now) / 1_000_000_000), for: sessionId)
            if deadline - now < tick {
                // Land the final tick exactly on the deadline instead of overshooting by up to 100ms
                timer.schedule(deadline: DispatchTime(uptimeNanoseconds: deadline))
            }
        }
        timer.resume()
    }

    private func _beginRunningSession(sessionId: UUID) {
        guard isCurrent(sessionId) else { return }

        sessionStartDate = Date()
        sessionStartUptime = DispatchTime.now().uptimeNanoseconds
        lastClickUptime = 0
        totalClicksCount = 0

        let initialStats = SessionStats(
            clicksCount: 0,
            startTime: sessionStartDate,
            elapsedSeconds: 0,
            effectiveCPS: sessionConfig.cps
        )
        _publish(.running(stats: initialStats), for: sessionId)

        // Setup high-precision click timer
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: engineQueue)
        self.clickTimer = timer
        _scheduleClickTimer(timer, interval: sessionConfig.intervalSeconds)
        timer.setEventHandler { [weak self] in
            self?._clickTick(sessionId: sessionId)
        }
        timer.resume()

        // Setup HUD stats refresh timer (every 0.2s). Also enforces the duration limit so it
        // is honoured promptly even at low CPS.
        let stats = DispatchSource.makeTimerSource(queue: engineQueue)
        self.statsTimer = stats
        stats.schedule(deadline: .now() + 0.2, repeating: 0.2)
        stats.setEventHandler { [weak self] in
            guard let self = self, self.isCurrent(sessionId) else { return }

            let elapsed = self._elapsedSeconds()
            if self._durationExceeded(elapsed) {
                self._finishSession(sessionId)
                return
            }

            let clicks = self.totalClicksCount
            let effectiveCPS = elapsed > 0.05 ? Double(clicks) / elapsed : self.sessionConfig.cps
            let updatedStats = SessionStats(
                clicksCount: clicks,
                startTime: self.sessionStartDate,
                elapsedSeconds: elapsed,
                effectiveCPS: effectiveCPS
            )
            self._publish(.running(stats: updatedStats), for: sessionId)
        }
        stats.resume()
    }

    private func _scheduleClickTimer(_ timer: DispatchSourceTimer, interval: Double) {
        // Monotonic cadence scheduling
        let intervalMicros = max(100, Int(interval * 1_000_000))
        let leewayMicros = max(20, min(200, intervalMicros / 5))
        timer.schedule(
            deadline: .now(),
            repeating: .microseconds(intervalMicros),
            leeway: .microseconds(leewayMicros)
        )
        scheduledInterval = interval
    }

    private func _clickTick(sessionId: UUID) {
        guard isCurrent(sessionId) else { return }
        let config = sessionConfig

        // Avoid catch-up bursts after a stall (or a reschedule): require most of an interval since the last click
        let now = DispatchTime.now().uptimeNanoseconds
        let minIntervalNs = UInt64(config.intervalSeconds * 0.70 * 1_000_000_000)
        if lastClickUptime != 0 && now &- lastClickUptime < minIntervalNs {
            return
        }
        lastClickUptime = now

        let holdDuration = min(ClickEngine.maxHoldDuration, config.intervalSeconds * 0.4)
        let success = adapter.postClick(
            button: config.button,
            focusWindow: config.focusWindow,
            holdDuration: holdDuration,
            shouldProceed: { [weak self] in self?.isCurrent(sessionId) ?? false }
        )
        if success {
            totalClicksCount += 1
        }

        if config.clickLimitEnabled && totalClicksCount >= config.clickLimit {
            _finishSession(sessionId)
            return
        }

        if _durationExceeded(_elapsedSeconds()) {
            _finishSession(sessionId)
        }
    }

    private func _elapsedSeconds() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds &- sessionStartUptime) / 1_000_000_000
    }

    private func _durationExceeded(_ elapsed: Double) -> Bool {
        sessionConfig.stopDurationEnabled && elapsed >= sessionConfig.stopDurationSeconds
    }

    /// Ends a session from inside the engine (limit reached).
    private func _finishSession(_ sessionId: UUID) {
        guard clearSession(ifCurrent: sessionId) else { return }
        _teardown()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isSessionActive else { return }
            self.state = .stopped
        }
    }

    private func _teardown() {
        self.countdownTimer?.cancel()
        self.countdownTimer = nil

        self.clickTimer?.cancel()
        self.clickTimer = nil

        self.statsTimer?.cancel()
        self.statsTimer = nil

        // Always resolve any unresolved button down state
        if self.adapter.isButtonDown {
            _ = self.adapter.releaseButton(button: self.sessionConfig.button)
        }
    }

    deinit {
        countdownTimer?.cancel()
        clickTimer?.cancel()
        statsTimer?.cancel()
    }
}
