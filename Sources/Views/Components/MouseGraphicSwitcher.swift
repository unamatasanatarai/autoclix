import SwiftUI

public struct LeftButtonShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2
        let gap: CGFloat = 2.0
        let ww: CGFloat = 5.5
        let wh: CGFloat = 13.0
        let cy = h / 2

        let innerX = cx - gap / 2
        let notchX = cx - ww / 2 - 1.25
        let notchTopY = cy - wh / 2 - 1.0
        let notchBottomY = cy + wh / 2 + 1.0

        path.move(to: CGPoint(x: 5, y: h))
        path.addLine(to: CGPoint(x: innerX - 1.5, y: h))
        path.addQuadCurve(to: CGPoint(x: innerX, y: h - 1.5), control: CGPoint(x: innerX, y: h))
        path.addLine(to: CGPoint(x: innerX, y: notchBottomY))
        path.addQuadCurve(to: CGPoint(x: notchX, y: cy + wh / 2 - 1.5), control: CGPoint(x: notchX, y: notchBottomY))
        path.addLine(to: CGPoint(x: notchX, y: cy - wh / 2 + 1.5))
        path.addQuadCurve(to: CGPoint(x: innerX, y: notchTopY), control: CGPoint(x: notchX, y: notchTopY))
        path.addLine(to: CGPoint(x: innerX, y: 1.5))
        path.addQuadCurve(to: CGPoint(x: innerX - 1.5, y: 0), control: CGPoint(x: innerX, y: 0))
        path.addLine(to: CGPoint(x: 6, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: 6), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - 5))
        path.addQuadCurve(to: CGPoint(x: 5, y: h), control: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

public struct RightButtonShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2
        let gap: CGFloat = 2.0
        let ww: CGFloat = 5.5
        let wh: CGFloat = 13.0
        let cy = h / 2

        let innerX = cx + gap / 2
        let notchX = cx + ww / 2 + 1.25
        let notchTopY = cy - wh / 2 - 1.0
        let notchBottomY = cy + wh / 2 + 1.0

        path.move(to: CGPoint(x: w - 5, y: h))
        path.addLine(to: CGPoint(x: innerX + 1.5, y: h))
        path.addQuadCurve(to: CGPoint(x: innerX, y: h - 1.5), control: CGPoint(x: innerX, y: h))
        path.addLine(to: CGPoint(x: innerX, y: notchBottomY))
        path.addQuadCurve(to: CGPoint(x: notchX, y: cy + wh / 2 - 1.5), control: CGPoint(x: notchX, y: notchBottomY))
        path.addLine(to: CGPoint(x: notchX, y: cy - wh / 2 + 1.5))
        path.addQuadCurve(to: CGPoint(x: innerX, y: notchTopY), control: CGPoint(x: notchX, y: notchTopY))
        path.addLine(to: CGPoint(x: innerX, y: 1.5))
        path.addQuadCurve(to: CGPoint(x: innerX + 1.5, y: 0), control: CGPoint(x: innerX, y: 0))
        path.addLine(to: CGPoint(x: w - 6, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: 6), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - 5))
        path.addQuadCurve(to: CGPoint(x: w - 5, y: h), control: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

public struct MouseGraphicSwitcher: View {
    @Binding public var selectedButton: MouseButton

    private let mouseWidth: CGFloat = 32
    private let mouseHeight: CGFloat = 24
    private let wheelWidth: CGFloat = 5.5
    private let wheelHeight: CGFloat = 13.0

    public init(selectedButton: Binding<MouseButton>) {
        self._selectedButton = selectedButton
    }

    public var body: some View {
        Button(action: cycleNextButton) {
            ZStack {
                // Background touch area covering the entire mouse bounds
                Color.white.opacity(0.001)
                    .frame(width: mouseWidth, height: mouseHeight)

                // Left Button
                LeftButtonShape()
                    .fill(selectedButton == .left ? Theme.textPrimary : Color.clear)
                    .overlay(
                        LeftButtonShape()
                            .stroke(
                                selectedButton == .left ? Theme.textPrimary : Theme.textSecondary.opacity(0.5),
                                lineWidth: 1.2
                            )
                    )

                // Right Button
                RightButtonShape()
                    .fill(selectedButton == .right ? Theme.textPrimary : Color.clear)
                    .overlay(
                        RightButtonShape()
                            .stroke(
                                selectedButton == .right ? Theme.textPrimary : Theme.textSecondary.opacity(0.5),
                                lineWidth: 1.2
                            )
                    )

                // Middle Wheel Capsule
                RoundedRectangle(cornerRadius: wheelWidth / 2)
                    .fill(selectedButton == .middle ? Theme.textPrimary : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: wheelWidth / 2)
                            .stroke(
                                selectedButton == .middle ? Theme.textPrimary : Theme.textSecondary.opacity(0.5),
                                lineWidth: 1.2
                            )
                    )
                    .frame(width: wheelWidth, height: wheelHeight)
            }
            .frame(width: mouseWidth, height: mouseHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .help("Click to toggle: currently \(selectedButton.displayName) (Left → Middle → Right)")
        .animation(.easeInOut(duration: 0.12), value: selectedButton)
    }

    private func cycleNextButton() {
        switch selectedButton {
        case .left:
            selectedButton = .middle
        case .middle:
            selectedButton = .right
        case .right:
            selectedButton = .left
        }
    }
}
