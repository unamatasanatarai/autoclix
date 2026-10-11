import SwiftUI

public struct StatusCardView: View {
    @ObservedObject var engine: ClickEngine
    @ObservedObject var permissionManager: PermissionManager

    public init(engine: ClickEngine, permissionManager: PermissionManager) {
        self.engine = engine
        self.permissionManager = permissionManager
    }

    public var body: some View {
        switch engine.state {
        case .running(let stats):
            HStack(spacing: 6) {
                Text("\(stats.clicksCount) clicks")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))

                Text("•")
                    .font(.system(size: 9))

                Text(formatTime(stats.elapsedSeconds))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))

                Text("•")
                    .font(.system(size: 9))

                Text(String(format: "%.1f CPS", stats.effectiveCPS))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)

        case .waiting(let remaining):
            Text(String(format: "Starting in %.1fs...", remaining))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)

        case .permissionRequired:
            VStack(spacing: 3) {
                Text("Accessibility access required to dispatch clicks.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Theme.orange.opacity(0.12))
            .cornerRadius(6)

        case .error(let msg):
            Text(msg)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Theme.orange.opacity(0.12))
                .cornerRadius(6)

        case .stopped:
            EmptyView()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

