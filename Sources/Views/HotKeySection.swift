import SwiftUI
import AppKit

public struct HotKeySection: View {
    @ObservedObject var hotKeyManager: HotKeyManager
    @State private var isHovered: Bool = false
    @State private var anchorView: NSView? = nil

    public init(hotKeyManager: HotKeyManager) {
        self.hotKeyManager = hotKeyManager
    }

    public var body: some View {
        Button(action: showPresetsMenu) {
            Text(hotKeyManager.currentConfig.displayString.replacingOccurrences(of: " (Default)", with: ""))
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundColor(isHovered ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(isHovered ? Theme.surfaceHover : Color.clear)
                .cornerRadius(3)
        }
        .buttonStyle(PlainButtonStyle())
        .background(MenuAnchorView { anchorView = $0 })
        .onHover { isHovered = $0 }
        .help("Global shortcut: \(hotKeyManager.currentConfig.displayString)")
    }

    private func showPresetsMenu() {
        let menu = NSMenu()
        for preset in HotKeyConfiguration.presets {
            let isCurrent = preset.keyCode == hotKeyManager.currentConfig.keyCode &&
                preset.modifiers == hotKeyManager.currentConfig.modifiers
            let item = NSMenuItem(
                title: isCurrent ? "✓ " + preset.displayString : preset.displayString,
                action: #selector(HotKeyMenuHelper.selectPreset(_:)),
                keyEquivalent: ""
            )
            item.representedObject = preset
            item.target = HotKeyMenuHelper.shared
            menu.addItem(item)
        }

        HotKeyMenuHelper.shared.onSelect = { [weak hotKeyManager] preset in
            _ = hotKeyManager?.register(config: preset)
        }

        if let anchor = anchorView {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: anchor)
        } else if let event = NSApp.currentEvent, let window = event.window {
            menu.popUp(positioning: nil, at: event.locationInWindow, in: window.contentView)
        }
    }
}

private final class HotKeyMenuHelper: NSObject {
    static let shared = HotKeyMenuHelper()
    var onSelect: ((HotKeyConfiguration) -> Void)?

    @objc func selectPreset(_ sender: NSMenuItem) {
        if let config = sender.representedObject as? HotKeyConfiguration {
            onSelect?(config)
        }
    }
}

private struct MenuAnchorView: NSViewRepresentable {
    let onAttach: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onAttach(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onAttach(nsView)
        }
    }
}
