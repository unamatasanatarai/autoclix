import SwiftUI

public struct MainView: View {
    @ObservedObject var engine: ClickEngine
    @ObservedObject var hotKeyManager: HotKeyManager
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var appState: AppState = .shared
    public var onHideWindow: (() -> Void)?
    public var onSizeChange: ((CGSize) -> Void)?

    @State private var isHideHovered: Bool = false

    public init(
        engine: ClickEngine = .shared,
        hotKeyManager: HotKeyManager = .shared,
        permissionManager: PermissionManager = .shared,
        appState: AppState = .shared,
        onHideWindow: (() -> Void)? = nil,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        self.engine = engine
        self.hotKeyManager = hotKeyManager
        self.permissionManager = permissionManager
        self.appState = appState
        self.onHideWindow = onHideWindow
        self.onSizeChange = onSizeChange
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header: Close on left, AutoCliX on right
            HStack(spacing: 6) {
                // Close / Hide Window button
                Button(action: {
                    onHideWindow?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isHideHovered ? Theme.textPrimary : Theme.textSecondary)
                        .frame(width: 16, height: 16)
                        .background(isHideHovered ? Theme.surfaceHover : Color.clear)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHideHovered = $0 }
                .help("Close Window")

                Spacer()

                HStack(spacing: 5) {
                    Text("AutoCliX")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Image(nsImage: StatusBarIconHelper.createIcon(for: engine.state))
                        .renderingMode(engine.state.isActive ? .original : .template)
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 14, height: 14)
                }
            }

            // Double Cmd+Q quit confirmation notice
            if let notice = appState.quitNotice {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 9))
                    Text(notice)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Theme.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Theme.orange.opacity(0.14))
                .cornerRadius(5)
                .transition(.opacity)
            }

            // Mouse Button & Rate Configuration
            ClickConfigSection(engine: engine)

            // Primary Action Button (Play / Stop) in vertical center
            ActionButtonView(engine: engine, hotKeyManager: hotKeyManager, permissionManager: permissionManager)
                .padding(.vertical, 2)

            // Contextual Live Status (HUD)
            StatusCardView(engine: engine, permissionManager: permissionManager)

            // Timers & Limits in 3 columns
            TimerConfigSection(engine: engine)

            // Bottom bar: Mode switch (Focus | Background) & Global shortcut
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: {
                        engine.config.focusWindow = true
                    }) {
                        Text("Focus")
                            .font(.system(size: 9.5, weight: engine.config.focusWindow ? .semibold : .regular))
                            .foregroundColor(engine.config.focusWindow ? Theme.textPrimary : Theme.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Focus mode: Clicks activate and raise windows to front")

                    Button(action: {
                        engine.config.focusWindow = false
                    }) {
                        Text("Background")
                            .font(.system(size: 9.5, weight: !engine.config.focusWindow ? .semibold : .regular))
                            .foregroundColor(!engine.config.focusWindow ? Theme.textPrimary : Theme.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Background mode: Clicks without stealing focus or raising windows")
                }

                Spacer()

                // Global shortcut selector
                HotKeySection(hotKeyManager: hotKeyManager)
            }
            .frame(height: 20)
        }
        .padding(12)
        .frame(width: 260)
        .background(Theme.bgWindow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: WindowSizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(WindowSizePreferenceKey.self) { size in
            onSizeChange?(size)
        }
    }
}

public struct WindowSizePreferenceKey: PreferenceKey {
    public static var defaultValue: CGSize = .zero
    public static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

