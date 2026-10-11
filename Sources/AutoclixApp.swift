import Cocoa
import SwiftUI
import Combine

public final class AppState: ObservableObject {
    public static let shared = AppState()
    @Published public var quitNotice: String? = nil
}

public final class AutoclixPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    public override func standardWindowButton(_ button: NSWindow.ButtonType) -> NSButton? { nil }

    // Do not autofocus on anything
    public override var initialFirstResponder: NSView? {
        get { nil }
        set { }
    }

    public override func selectKeyView(preceding view: NSView) {
        // Prevent automatic key view loop selection
    }

    public override func selectKeyView(following view: NSView) {
        // Prevent automatic key view loop selection
    }
}

@main
public final class AutoclixApp: NSObject, NSApplicationDelegate {
    public static func main() {
        let app = NSApplication.shared
        let delegate = AutoclixApp()
        app.delegate = delegate
        app.run()
    }

    private var statusItem: NSStatusItem?
    private var window: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    private let engine = ClickEngine.shared
    private let hotKeyManager = HotKeyManager.shared
    private let permissionManager = PermissionManager.shared

    private var lastCmdQTime: TimeInterval = 0
    private var quitNoticeTimer: DispatchWorkItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app activation policy
        NSApp.setActivationPolicy(.accessory)

        setupHotKeyTrigger()
        setupStatusItem()
        setupWindow()
        setupKeyMonitor()
        setupStateObservation()
        setupLifecycleObservers()

        // Give menu bar item a brief tick to establish screen frame, then show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showWindow()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        hotKeyManager.unregister()
    }

    // MARK: - Setup Components

    private func setupHotKeyTrigger() {
        hotKeyManager.onTrigger = { [weak self] in
            self?.engine.toggle()
        }
    }

    private func setupKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "q" {
                self.handleDoubleCmdQ()
                return nil
            }
            return event
        }
    }

    private func handleDoubleCmdQ() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastCmdQTime <= 1.5 {
            NSApp.terminate(nil)
        } else {
            lastCmdQTime = now
            quitNoticeTimer?.cancel()
            withAnimation(.easeInOut(duration: 0.15)) {
                AppState.shared.quitNotice = "Press ⌘Q again to quit"
            }
            let item = DispatchWorkItem {
                withAnimation(.easeInOut(duration: 0.15)) {
                    AppState.shared.quitNotice = nil
                }
            }
            quitNoticeTimer = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = createStatusBarIcon(for: .stopped)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item
    }

    private func setupWindow() {
        let initialWidth: CGFloat = 260
        let initialHeight: CGFloat = 244
        let panel = AutoclixPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView: MainView(
            engine: engine,
            hotKeyManager: hotKeyManager,
            permissionManager: permissionManager,
            appState: AppState.shared,
            onHideWindow: { [weak self] in
                self?.hideWindow()
            },
            onSizeChange: { [weak self] newSize in
                self?.updateWindowSize(newSize)
            }
        ))
        panel.contentView = hostingView

        self.window = panel
    }

    public func hideWindow() {
        window?.orderOut(nil)
    }

    private func updateWindowSize(_ newSize: CGSize) {
        guard let window = window, newSize.height > 50, newSize.width > 50 else { return }
        var frame = window.frame
        let deltaY = newSize.height - frame.height
        frame.origin.y -= deltaY
        frame.size.width = newSize.width
        frame.size.height = newSize.height
        window.setFrame(frame, display: true, animate: false)
    }

    private func setupStateObservation() {
        engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateStatusItemIcon(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemIcon(for state: EngineState) {
        guard let button = statusItem?.button else { return }
        button.image = createStatusBarIcon(for: state)

        switch state {
        case .running:
            button.toolTip = "AutoCliX: Running"
        case .waiting:
            button.toolTip = "AutoCliX: Waiting"
        case .permissionRequired:
            button.toolTip = "AutoCliX: Accessibility Permission Required"
        default:
            button.toolTip = "AutoCliX: Ready"
        }
    }

    public func createStatusBarIcon(for state: EngineState) -> NSImage {
        StatusBarIconHelper.createIcon(for: state)
    }

    private func setupLifecycleObservers() {
        let ws = NSWorkspace.shared.notificationCenter

        // Stop safely on computer sleep
        ws.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine.stop()
        }

        // Stop safely on user session lock/switch
        ws.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine.stop()
        }
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(at: sender)
        } else {
            toggleWindow()
        }
    }

    public func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    public func showWindow() {
        guard let window = window else { return }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowWidth = window.frame.width
        let windowHeight = window.frame.height

        var targetX: CGFloat
        var targetY: CGFloat

        if let button = statusItem?.button,
           let buttonWindow = button.window,
           buttonWindow.frame.minY > 100 {
            let buttonRect = buttonWindow.convertToScreen(button.frame)
            targetX = buttonRect.midX - (windowWidth / 2)
            targetY = buttonRect.minY - windowHeight - 8
        } else {
            targetX = screen.maxX - windowWidth - 20
            targetY = screen.maxY - windowHeight - 12
        }

        targetX = max(screen.minX + 12, min(targetX, screen.maxX - windowWidth - 12))
        targetY = max(screen.minY + 12, min(targetY, screen.maxY - windowHeight - 12))

        window.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showContextMenu(at sender: NSStatusBarButton) {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "AutoCliX 1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let toggleTitle = engine.state.isActive ? "Stop Clicking" : "Start Clicking"
        let toggleItem = NSMenuItem(title: "\(toggleTitle) (\(hotKeyManager.currentConfig.displayString))", action: #selector(toggleEngineAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let showWindowItem = NSMenuItem(title: "Open Configuration Window", action: #selector(openWindowAction), keyEquivalent: "")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit AutoCliX", action: #selector(quitAction), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // reset so subsequent left clicks trigger action
    }

    @objc private func toggleEngineAction() {
        engine.toggle()
    }

    @objc private func openWindowAction() {
        showWindow()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
