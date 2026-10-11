import SwiftUI

public struct ActionButtonView: View {
    @ObservedObject var engine: ClickEngine
    @ObservedObject var hotKeyManager: HotKeyManager
    @ObservedObject var permissionManager: PermissionManager

    @State private var isPermissionHovered = false

    public init(engine: ClickEngine, hotKeyManager: HotKeyManager, permissionManager: PermissionManager) {
        self.engine = engine
        self.hotKeyManager = hotKeyManager
        self.permissionManager = permissionManager
    }

    public var body: some View {
        if !permissionManager.isAccessibilityGranted {
            Button(action: {
                permissionManager.promptForPermission()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9))

                    Text("Grant Permission")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Theme.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isPermissionHovered ? Theme.orange.opacity(0.24) : Theme.orange.opacity(0.14))
                .cornerRadius(5)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isPermissionHovered = $0 }
        } else {
            Button(action: {
                engine.toggle()
            }) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: buttonIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .offset(x: engine.state.isActive ? 0 : 1)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var buttonIcon: String {
        switch engine.state {
        case .running, .waiting:
            return "stop.fill"
        default:
            return "play.fill"
        }
    }

    private var buttonColor: Color {
        switch engine.state {
        case .running:
            return Theme.orange
        case .waiting:
            return Theme.orange
        default:
            return Theme.emerald
        }
    }
}

