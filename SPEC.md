# Autoclix — Product & Engineering Specification

**Product:** Autoclix  
**Platform:** macOS  
**Product type:** Native menu-bar utility  
**Version:** 1.0  
**Status:** Proposed specification

## 1. Product vision

Autoclix is a lightweight, native macOS autoclicker that generates mouse-button events through macOS system-level input-event mechanisms.

Users can choose which mouse button to click, configure the clicking frequency, and start or stop clicking using the interface or a global keyboard shortcut.

Autoclix prioritizes reliability, predictable behavior, a minimal interface, and safe cancellation over feature count.

### Core principles

1. **Native interaction:** Generate system-level mouse events rather than simulating clicks inside individual applications.
2. **User control:** Clicking must never start unexpectedly, and stopping must reliably prevent further click sequences.
3. **Predictability:** Click rate, button selection, timers, and state transitions must have explicitly defined behavior.
4. **Minimalism:** Expose essential controls first; defer features until there is evidence that users need them.
5. **Privacy:** Work entirely offline, collect no telemetry, and store preferences locally.

### What Autoclix is not

Autoclix is not a macro recorder, virtual mouse driver, remote-control tool, or general-purpose automation platform. It does not promise to bypass application security mechanisms or reproduce physical hardware input in environments that reject synthetic events.

---

## 2. Target users and use cases

Autoclix serves users who need repeated mouse clicks without manually operating the mouse.

Representative use cases include:

- Repetitive clicking in desktop applications.
- Repeated left, right, or middle clicks.
- Performing clicks at a consistent, configurable frequency.
- Starting clicks after a delay to allow time to position the pointer.
- Stopping automatically after a specified duration or number of clicks.

These use cases define the initial product direction. Additional workflows must be validated before they expand the scope.

---

## 3. Core user interface

The primary interface should follow the provided reference screenshot: a compact, dark macOS window with native-looking controls, clear grouping, and minimal visual noise.

### 3.1 Click configuration

**Mouse button**

A dropdown allows the user to choose:

- Left
- Right
- Middle

Side buttons may be added later if their system-level event mapping and compatibility can be validated.

Changing the selected button must not start clicking.

**Click frequency**

- Numeric field with increment/decrement controls.
- Displayed in clicks per second (CPS).
- Default: 8 CPS.
- Configurable minimum and maximum values.
- The maximum permitted rate must be established through implementation benchmarks and reliability testing.

One CPS represents one completed click, consisting of a button-down and button-up event.

At 8 CPS, the target interval between click starts is 125 milliseconds.

**Start delay**

- Optional checkbox to enable or disable the delay.
- Numeric duration field.
- Unit selection, initially seconds.
- When enabled, clicking begins after the configured delay.
- The app must display a Waiting state during the delay.
- Stopping during the delay cancels the pending start.

**Stop after duration**

- Optional checkbox.
- Numeric duration field.
- Unit selection, initially seconds.
- When enabled, the clicking session ends after the configured duration.
- The timer starts when the session begins, not while the app is waiting for a start delay.

**Session status**

Display one of the following states:

- Stopped
- Waiting
- Running
- Paused, if pausing is supported in the implementation
- Permission required
- Error

A prominent Start or Stop button must reflect the current state.

The UI must not display Running until the engine has successfully entered its running state.

### 3.2 Global keyboard shortcut

Provide a configurable global shortcut to start and stop clicking.

- Initial default: Option + A.
- Check for registration conflicts.
- Report registration failures clearly.
- Allow the user to configure a replacement shortcut.
- Unregister the shortcut when the application exits.

The global shortcut must not be the only way to stop clicking. The app must retain a visible Stop control.

### 3.3 Menu-bar presence

Autoclix runs as a native menu-bar utility.

- No Dock icon by default.
- A menu-bar item exposes the current state.
- Clicking the item opens the main configuration window.
- The app can be quit normally.
- The interface remains responsive during sustained clicking.

The exact menu-bar presentation can be refined during UI implementation.

---

## 4. Mouse-event engine

This is the most important technical component and the principal release risk.

### 4.1 System-level event generation

Implement the application in Swift, using SwiftUI with AppKit integration where necessary.

Use Core Graphics Quartz Event Services or another appropriate native macOS mechanism to generate mouse-button events.

The implementation must not depend on:

- JavaScript or DOM event simulation.
- Browser-specific click automation.
- Application-specific keyboard shortcuts as a substitute for mouse clicks.
- A virtual mouse device.
- A busy-waiting loop.

The precise event-posting mechanism must be selected through a technical prototype. Compare the relevant posting locations and permission requirements, then select the least-privileged approach that satisfies the supported use cases.

Do not assume that every event-posting mechanism offers the same delivery characteristics or permissions.

### 4.2 Click semantics

A complete click consists of:

1. Selecting the configured button.
2. Determining the appropriate pointer position for the click.
3. Posting a mouse-button-down event.
4. Posting the corresponding mouse-button-up event.
5. Recording the completion of the click sequence.

The event adapter must map each supported button to the appropriate native event types and button identifiers.

Clicks must occur at the current pointer position unless a future feature explicitly defines different behavior.

Autoclix must not reposition the pointer as part of normal clicking.

### 4.3 Event pairing and cancellation

Every generated mouse-down event must have a corresponding mouse-up attempt.

- Never begin a second click while the previous generated button state is unresolved.
- If a stop request arrives between mouse-down and mouse-up, prioritize completing the release sequence.
- After the current sequence is resolved, do not begin another click.
- On internal errors or shutdown, attempt to release any outstanding synthetic button state.
- Treat recovery as best effort where macOS does not guarantee that an event will be delivered or processed.

A Stop request must prevent new click sequences as soon as the engine processes the request. The specification does not promise instantaneous cancellation in the middle of an already-started event sequence.

### 4.4 Delivery limitations

System-level synthetic mouse events can behave like ordinary mouse input in supported applications, but their behavior is not guaranteed to be identical to physical hardware input in every environment.

Some applications, secure interfaces, games, or protected environments may reject synthetic events.

Autoclix must:

- Define its tested compatibility scope.
- Avoid claiming universal application compatibility.
- Distinguish successful event posting from confirmed application behavior.
- Fail transparently when required event generation is unavailable.

---

## 5. Click scheduling and timing

### 5.1 Scheduling model

Use a monotonic time source and a dedicated scheduling mechanism. Do not block the main UI thread.

The target cadence is defined by the configured clicks per second.

The scheduler must:

- Avoid accumulating timing drift unnecessarily.
- Avoid catch-up bursts after delayed execution.
- Skip missed deadlines rather than generating a rapid burst of overdue clicks.
- Avoid overlapping click sequences.
- Respond promptly to Stop requests.
- Recalculate scheduling when a new session starts.

### 5.2 Timing guarantees

CPS is a target, not an unconditional delivery guarantee.

Actual observed click rates can be affected by system load, operating-system scheduling, and event-posting behavior.

The application must distinguish between:

- Configured click rate.
- Observed click generation rate during engineering validation.
- Any limitations or throttling applied by the engine.

The initial performance target is an average generation rate within ±5% of 8 CPS over a 60-second run under normal test conditions.

This is a proposed benchmark to validate, not a claim about current performance.

The maximum supported CPS must be determined through testing rather than chosen arbitrarily.

---

## 6. Application state machine

All click-generation state must be owned by a single engine component.

UI controls, timers, global shortcuts, and permission changes must send commands to that component rather than independently modifying state.

### State definitions

**Stopped:** No click sequences are being generated.

**Waiting:** A configured start delay is pending.

**Running:** The engine is actively generating click sequences.

**Paused:** Clicking is temporarily suspended, if pause behavior is implemented.

**Permission required:** The application cannot proceed until a required permission is granted.

**Error:** An unrecoverable session error has occurred; clicking is stopped.

### Transition rules

- Starting without a delay transitions from Stopped to Running.
- Starting with a delay transitions from Stopped to Waiting.
- Completion of the delay transitions from Waiting to Running.
- Stopping from any active state transitions to Stopped after any necessary button-release handling.
- A permission failure or fatal engine error terminates the current session.
- Repeated or conflicting commands must not create overlapping sessions.
- Stale timers from previous sessions must not restart clicking.

The engine should serialize commands and use session identifiers or equivalent cancellation safeguards so delayed work cannot affect a newer session.

---

## 7. Permissions and lifecycle

### 7.1 Permission management

Determine the precise macOS permissions required by the selected implementation.

- Check required permissions before starting.
- Explain why a permission is needed.
- Provide clear navigation guidance to System Settings.
- Recheck authorization when the app becomes active again.
- If a required permission is revoked during a session, stop safely and report the problem.
- Never silently report success when clicking cannot proceed.

Do not request unrelated permissions or attempt to circumvent operating-system security controls.

### 7.2 Lifecycle behavior

Handle the following explicitly:

- Application launch.
- Application termination.
- Computer sleep and wake.
- Screen locking, where relevant.
- Switching between applications.
- Permission revocation.
- Global-hotkey registration failure.
- Unexpected engine exceptions.
- System load causing delayed scheduling.

At shutdown, cancel pending scheduling work and attempt to release outstanding synthetic button state.

Autoclix must start in the Stopped state after every launch.

---

## 8. Architecture

Keep the event engine independent from the user interface.

### UI layer

Responsible for configuration, status presentation, and user feedback.

### Hotkey manager

Responsible for shortcut registration, conflict reporting, and cleanup.

### Permission manager

Responsible for authorization checks and permission-related state changes.

### Click engine

Owns session state, configuration validation, click serialization, and cancellation.

### Scheduler

Computes click deadlines, manages delays and duration limits, and controls click cadence.

### Event adapter

Maps abstract click requests to native macOS mouse events.

### Persistence layer

Stores user preferences locally.

### Engineering principles

- Prefer simple, explicit interfaces between components.
- Avoid unnecessary frameworks and dependencies.
- Keep scheduling independent of the main UI thread.
- Unit-test scheduling and state transitions without generating real mouse events.
- Allow event generation to be replaced with a test double during automated tests.

---

## 9. Safety and failure handling

Autoclix must default to Stopped and never begin clicking without an explicit user action.

Required safeguards:

- A visible Stop control.
- A configurable global start/stop shortcut.
- Immediate cancellation of future scheduled click sequences when Stop is processed.
- Reliable event-pairing logic.
- A configurable maximum click rate.
- An optional maximum session duration.
- An optional click-count limit, provided it can be implemented without unnecessary complexity.
- Clear feedback when clicking fails or permissions are unavailable.

The optional limits should not require intrusive prompts on every session.

Errors must not leave the UI reporting Running when the engine is no longer active.

The product should minimize the chance of unintended interactions, but must not promise absolute prevention of every unintended click or guaranteed event delivery.

---

## 10. Preferences and privacy

Persist essential preferences locally:

- Selected mouse button.
- Click rate.
- Start delay configuration.
- Stop-duration configuration.
- Global shortcut.
- Optional safety limits.

The application must not persistably record pointer-position history.

Core functionality requires no network connection, accounts, analytics, or cloud synchronization.

Launch at login is excluded from the initial release.

---

## 11. Non-functional requirements

### Performance

- Keep the application responsive during sustained clicking.
- Avoid busy-waiting.
- Maintain low idle CPU and memory use.
- Establish supported click-rate limits through benchmarks.
- Ensure stopping does not depend on the main UI thread being free of blocking operations.

### Reliability

- No overlapping sessions.
- No stale timers restarting a stopped session.
- Every mouse-down has a corresponding mouse-up attempt.
- No scheduled work continues after normal application shutdown.
- Errors are reported rather than silently ignored.

### Compatibility

- Native Apple Silicon support.
- Intel support only if it is an explicit distribution requirement.
- Defined and tested minimum macOS version.
- Documented limits for applications that reject synthetic input.

### Accessibility

- Keyboard-accessible controls.
- Meaningful VoiceOver labels.
- Readable status indicators.
- Clear distinction between enabled options and active behavior.

---

## 12. Testing strategy

### Unit tests

Cover:

- Button-to-event mapping.
- Click interval calculation.
- Click-count limits.
- Start-delay calculations.
- Stop-duration calculations.
- State transitions.
- Cancellation and stale-timer prevention.
- Event-pairing logic.
- Invalid configuration handling.

### Integration tests

Using the native event adapter, test actual system-level behavior with explicit permission setup.

Validate:

- Left, right, and middle clicks.
- Down/up event pairing.
- Pointer-position behavior.
- Global shortcut operation.
- Permission failure and recovery.
- Application shutdown while active.

### Application compatibility tests

Test representative supported applications, including:

- Finder.
- Safari.
- A standard AppKit test application.

Additional application classes can be added as actual user demand warrants.

These tests must verify observable outcomes. Successful event posting alone is insufficient to prove that a target application acted on the click.

### Timing tests

Measure click generation under controlled conditions.

For the proposed 8 CPS benchmark:

- Run for 60 seconds under normal system load.
- Measure generated click sequences using instrumentation or a test event sink.
- Target an average rate within ±5% of 8 CPS.
- Measure timing variation and record missed deadlines.
- Verify that delayed deadlines do not produce catch-up bursts.

Repeat tests under elevated system load to understand degradation, even if the nominal benchmark is not expected to hold under those conditions.

### Cancellation and fault tests

Validate:

- Stop during Waiting.
- Stop during Running.
- Rapid Start/Stop sequences.
- Permission loss during a session.
- Hotkey registration failure.
- Simulated event-posting failures.
- Shutdown with an outstanding synthetic button state.

---

## 13. Release acceptance criteria

Autoclix 1.0 is ready for release only when all applicable criteria pass.

1. The user can select Left, Right, or Middle.
2. Each selection maps to the intended native mouse-button event types.
3. Clicking works in the defined set of supported desktop applications.
4. The 8 CPS benchmark meets the proposed ±5% average-rate target over 60 seconds under normal test conditions.
5. Missed deadlines do not produce catch-up bursts.
6. Stop prevents any new click sequence after the command is processed.
7. Each generated mouse-down has a corresponding mouse-up attempt.
8. Required permission failures are reported clearly.
9. Permission loss terminates the active session safely.
10. The global shortcut can be configured and registered failure is reported.
11. The UI remains responsive during sustained clicking.
12. Shutdown cancels pending work and attempts to release outstanding synthetic button state.
13. The application starts Stopped.
14. Automated tests cover state transitions, scheduling, cancellation, and event mapping.
15. The product makes no claims of universal compatibility with physical mouse hardware behavior.

---

## 14. Scope decisions

### Release 1.0 — Required

- Native menu-bar application.
- Left, right, and middle button selection.
- Configurable clicks per second.
- Start and stop controls.
- Global keyboard shortcut.
- Optional start delay.
- Optional stop duration.
- Local preference persistence.
- Permission handling.
- Reliable scheduling, event pairing, and cancellation.
- Minimal, polished macOS interface.

### Deferred until validated

- Stationary-only clicking.
- Configurable pointer-movement tolerance.
- Launch at login.
- Randomized click intervals.
- Additional mouse buttons.
- Pause while holding Fn or another modifier.
- Click sounds.
- Macro recording or playback.
- Advanced automation integrations.

Deferred items should be implemented only when they demonstrate meaningful user value and can be supported without weakening reliability.

---

## 15. Implementation plan

### Phase 1 — Technical feasibility

Build a minimal Swift prototype that:

- Posts a left-button click.
- Tests right- and middle-button mapping.
- Establishes the required permissions.
- Validates behavior in representative applications.
- Measures click timing.
- Tests stopping between event sequences.

**Exit condition:** a documented event-generation mechanism, permission model, and compatibility assessment.

### Phase 2 — Reliable engine

Implement:

- State machine.
- Monotonic scheduler.
- Event adapter.
- Cancellation.
- Event-pairing safeguards.
- Safety limits.
- Automated unit tests.

**Exit condition:** repeatable tests pass without the user interface.

### Phase 3 — Native application

Implement the menu-bar utility, settings, status display, global shortcut, and local preferences.

**Exit condition:** all core workflows function through the user interface and the interface stays responsive.

### Phase 4 — Validation and release

Run timing, lifecycle, permission, compatibility, and cancellation tests. Resolve critical failures before distribution.

**Exit condition:** the release acceptance criteria pass and the supported compatibility scope is documented.

---

## 16. Product success criteria

Initial success is defined by correctness and usability rather than feature count.

The product should demonstrate:

- Reliable button selection and event mapping.
- Predictable click cadence within its tested operating limits.
- Safe cancellation.
- Clear permission behavior.
- Minimal resource use.
- A simple user experience with little configuration required.

Market assumptions should be validated through real user feedback before expanding the roadmap.

## Final product principle

**Autoclix should be a small macOS utility with a rigorously engineered core, transparent limitations, and predictable behavior.**

The first release must prove that native system-level clicking, timing, and cancellation work reliably. Only then should additional features be introduced.
