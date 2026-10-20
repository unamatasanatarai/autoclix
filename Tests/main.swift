import Foundation
import CoreGraphics

// Minimal test runner: Command Line Tools ship without XCTest, so tests are a plain executable.
// Engine state is published on the main queue, so waits spin the main run loop.

var failureCount = 0
var currentTest = ""

func test(_ name: String, _ body: () -> Void) {
    currentTest = name
    let before = failureCount
    body()
    print(failureCount == before ? "  ✓ \(name)" : "  ✗ \(name)")
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if !condition() {
        failureCount += 1
        print("    FAIL [\(currentTest)] line \(line): \(message)")
    }
}

@discardableResult
func waitUntil(timeout: TimeInterval = 2.0, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.main.run(until: Date().addingTimeInterval(0.005))
    }
    return condition()
}

func spin(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

final class FakeEventPoster: EventPosting {
    private let lock = NSLock()
    private var _clicks = 0
    private var _cancelled = 0
    private var _releases = 0
    private var _entered = false
    private var _isButtonDown = false
    private var _holdDurations: [TimeInterval] = []

    /// Simulates slow hit-testing / focus IPC before the cancellation point.
    var preProceedDelay: TimeInterval = 0

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var clicks: Int { locked { _clicks } }
    var cancelled: Int { locked { _cancelled } }
    var releases: Int { locked { _releases } }
    var entered: Bool { locked { _entered } }
    var holdDurations: [TimeInterval] { locked { _holdDurations } }

    var isButtonDown: Bool {
        get { locked { _isButtonDown } }
        set { locked { _isButtonDown = newValue } }
    }

    func postClick(button: MouseButton, focusWindow: Bool, holdDuration: TimeInterval, shouldProceed: () -> Bool) -> Bool {
        locked { _entered = true }
        if preProceedDelay > 0 {
            Thread.sleep(forTimeInterval: preProceedDelay)
        }
        guard shouldProceed() else {
            locked { _cancelled += 1 }
            return false
        }
        locked {
            _clicks += 1
            _holdDurations.append(holdDuration)
        }
        return true
    }

    func releaseButton(button: MouseButton) -> Bool {
        locked {
            _releases += 1
            _isButtonDown = false
        }
        return true
    }
}

func makeEngine(
    _ poster: FakeEventPoster,
    config: ClickConfiguration = ClickConfiguration(clickLimitEnabled: false),
    hasPermission: @escaping () -> Bool = { true },
    requestPermission: @escaping () -> Void = {}
) -> ClickEngine {
    let engine = ClickEngine(adapter: poster, preferences: nil, hasPermission: hasPermission, requestPermission: requestPermission)
    engine.config = config
    return engine
}

func isStopped(_ engine: ClickEngine) -> Bool {
    if case .stopped = engine.state { return true }
    return false
}

print("ClickConfiguration")

test("decoding clamps out-of-range persisted values") {
    let json = #"{"cps": 1e20, "clickLimit": -5, "startDelaySeconds": -1, "stopDurationSeconds": 1e9}"#
    let config = try! JSONDecoder().decode(ClickConfiguration.self, from: Data(json.utf8))
    expect(config.cps == ClickConfiguration.maxCPS, "cps clamped to max, got \(config.cps)")
    expect(config.clickLimit == 1, "clickLimit clamped to 1, got \(config.clickLimit)")
    expect(config.startDelaySeconds == ClickConfiguration.minSeconds, "start delay clamped to min")
    expect(config.stopDurationSeconds == ClickConfiguration.maxStopDurationSeconds, "duration clamped to max")
}

test("decoding fills missing fields with defaults") {
    let config = try! JSONDecoder().decode(ClickConfiguration.self, from: Data("{}".utf8))
    expect(config == ClickConfiguration(), "empty JSON decodes to defaults")
}

test("sanitized replaces non-finite values") {
    var config = ClickConfiguration()
    config.cps = .nan
    config.stopDurationSeconds = .infinity
    let sanitized = config.sanitized()
    expect(sanitized.cps == ClickConfiguration.defaultCPS, "NaN cps falls back to default")
    expect(sanitized.stopDurationSeconds == 10.0, "infinite duration falls back to default")
}

test("engine sanitizes direct field mutation") {
    let engine = makeEngine(FakeEventPoster())
    engine.config.cps = 5000
    expect(engine.config.cps == ClickConfiguration.maxCPS, "cps clamped on assignment, got \(engine.config.cps)")
    engine.config.clickLimit = 0
    expect(engine.config.clickLimit == 1, "clickLimit clamped on assignment")
}

print("ClickEngine")

test("click limit stops after exactly N clicks") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 200, clickLimitEnabled: true, clickLimit: 5))
    engine.start()
    expect(waitUntil { !engine.isSessionActive && isStopped(engine) }, "session ended and state is stopped")
    spin(0.1)
    expect(poster.clicks == 5, "exactly 5 clicks, got \(poster.clicks)")
}

test("toggle acts on session state synchronously") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 20, clickLimitEnabled: false))
    engine.toggle()
    expect(engine.isSessionActive, "active immediately after first toggle")
    engine.toggle()
    expect(!engine.isSessionActive, "inactive immediately after second toggle")
    spin(0.3)
    expect(isStopped(engine), "state settles to stopped, got \(engine.state)")
    expect(poster.clicks <= 1, "at most one click raced the stop, got \(poster.clicks)")
}

test("stop cancels a click blocked before button-down") {
    let poster = FakeEventPoster()
    poster.preProceedDelay = 0.2
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 10, clickLimitEnabled: false))
    engine.start()
    expect(waitUntil { poster.entered }, "click entered adapter")
    engine.stop()
    expect(waitUntil { poster.cancelled == 1 }, "in-flight click observed the stop")
    expect(poster.clicks == 0, "no click posted after stop, got \(poster.clicks)")
}

test("no clicks after stop") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 100, clickLimitEnabled: false))
    engine.start()
    expect(waitUntil { poster.clicks >= 3 }, "clicks are flowing")
    engine.stop()
    spin(0.05)
    let afterStop = poster.clicks
    spin(0.2)
    expect(poster.clicks == afterStop, "click count frozen after stop (\(afterStop) -> \(poster.clicks))")
}

test("stopAndWait releases a held button before returning") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 10, clickLimitEnabled: false))
    engine.start()
    expect(waitUntil { poster.clicks >= 1 }, "session running")
    poster.isButtonDown = true
    engine.stopAndWait()
    expect(poster.releases == 1, "button released synchronously, got \(poster.releases)")
    expect(!engine.isSessionActive, "session inactive")
}

test("duration limit is honoured at low CPS") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(
        cps: 1, stopDurationEnabled: true, stopDurationSeconds: 0.3, clickLimitEnabled: false
    ))
    let started = Date()
    engine.start()
    expect(waitUntil(timeout: 2) { isStopped(engine) && !engine.isSessionActive }, "session ended")
    let took = Date().timeIntervalSince(started)
    expect(took < 0.7, "stopped within ~0.3s + one stats tick, took \(took)s")
}

test("start delay defers the first click") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(
        cps: 50, startDelayEnabled: true, startDelaySeconds: 0.3, clickLimitEnabled: false
    ))
    engine.start()
    expect(waitUntil { engine.state.isWaiting }, "state is waiting")
    spin(0.2)
    expect(poster.clicks == 0, "no clicks during delay, got \(poster.clicks)")
    expect(waitUntil(timeout: 1) { poster.clicks > 0 }, "clicks begin after delay")
    engine.stop()
}

test("CPS change applies to a running session") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 2, clickLimitEnabled: false))
    engine.start()
    expect(waitUntil { poster.clicks == 1 }, "first click fires immediately")
    engine.config.cps = 100
    spin(0.3)
    expect(poster.clicks > 5, "new rate took effect, got \(poster.clicks) clicks")
    engine.stop()
}

test("hold duration scales down at high CPS") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 900, clickLimitEnabled: true, clickLimit: 3))
    engine.start()
    expect(waitUntil { !engine.isSessionActive }, "session ended")
    let maxHold = poster.holdDurations.max() ?? 1
    expect(maxHold <= 0.4 / 900 + 1e-9, "hold fits inside the interval, got \(maxHold)")

    let slowPoster = FakeEventPoster()
    let slowEngine = makeEngine(slowPoster, config: ClickConfiguration(cps: 8, clickLimitEnabled: true, clickLimit: 1))
    slowEngine.start()
    expect(waitUntil { !slowEngine.isSessionActive }, "slow session ended")
    expect(slowPoster.holdDurations.first == ClickEngine.maxHoldDuration, "full hold at low CPS")
}

test("missing permission blocks start and requests access") {
    let poster = FakeEventPoster()
    var requested = false
    let engine = makeEngine(poster, hasPermission: { false }, requestPermission: { requested = true })
    engine.start()
    expect(!engine.isSessionActive, "no session started")
    expect(waitUntil { requested }, "permission requested")
    expect(waitUntil {
        if case .permissionRequired = engine.state { return true }
        return false
    }, "state is permissionRequired")
    expect(poster.clicks == 0, "no clicks")
}

test("permission revocation stops a running session") {
    let poster = FakeEventPoster()
    let engine = makeEngine(poster, config: ClickConfiguration(cps: 50, clickLimitEnabled: false))
    engine.start()
    expect(waitUntil { poster.clicks > 0 }, "running")
    engine.permissionChanged(granted: false)
    expect(!engine.isSessionActive, "session stopped")
    spin(0.1)
    if case .permissionRequired = engine.state {} else {
        expect(false, "state should be permissionRequired, got \(engine.state)")
    }
    engine.permissionChanged(granted: true)
    expect(isStopped(engine), "state returns to stopped once granted")
}

print("Support")

test("own window registry hit-tests in global coordinates") {
    let registry = OwnWindowRegistry()
    registry.update(frames: [CGRect(x: 100, y: 50, width: 190, height: 230)])
    expect(registry.contains(CGPoint(x: 150, y: 100)), "point inside")
    expect(!registry.contains(CGPoint(x: 10, y: 10)), "point outside")
}

test("compact number text") {
    expect(NumberText.compact(3) == "3", "integer")
    expect(NumberText.compact(0.25) == "0.25", "trims trailing zeros")
    expect(NumberText.compact(0.0001) == "0.0001", "keeps 4 decimals")
    expect(!NumberText.isASCIIDigit("²") && !NumberText.isASCIIDigit("٣"), "rejects non-ASCII numerics")
}

if failureCount > 0 {
    print("\n\(failureCount) assertion(s) failed")
    exit(1)
}
print("\nAll tests passed")
