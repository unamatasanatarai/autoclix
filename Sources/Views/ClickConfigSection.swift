import SwiftUI

public struct ClickConfigSection: View {
    @ObservedObject var engine: ClickEngine
    @State private var hoveredButton: MouseButton? = nil
    @State private var cpsInputText: String = ""
    @State private var isDecrementHovered: Bool = false
    @State private var isIncrementHovered: Bool = false

    private let buttons: [MouseButton] = [.left, .middle, .right]

    public init(engine: ClickEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Mouse Button Segmented Switcher (Left | Middle | Right)
            HStack(spacing: 16) {
                ForEach(buttons) { btn in
                    let isSelected = engine.config.button == btn
                    let isHovered = hoveredButton == btn

                    Button(action: {
                        engine.config.button = btn
                    }) {
                        Text(btn.displayName)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? Theme.textPrimary : (isHovered ? Theme.textPrimary : Theme.textSecondary))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(height: 20)
                    .onHover { isHovering in
                        hoveredButton = isHovering ? btn : nil
                    }
                }
            }

            // Click Rate Stepper: [-  8 CPS  +] centered & balanced
            HStack(spacing: 6) {
                Spacer()

                // Decrement button
                Button(action: decrementCPS) {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isDecrementHovered ? Theme.textPrimary : Theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(isDecrementHovered ? Theme.surfaceHover : Color.clear)
                        .cornerRadius(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isDecrementHovered = $0 }
                .help("Hold Ctrl (±5), Alt (±10), Cmd (±50)")

                // Manual Input Box - Only [0-9], validated on the fly
                HStack(spacing: 3) {
                    NativeDigitsField(
                        text: $cpsInputText,
                        minValue: 1,
                        maxValue: 900,
                        fontSize: 13,
                        fontWeight: .semibold,
                        alignment: .right,
                        textColor: Theme.nsTextPrimary,
                        onChange: { newCPS in
                            engine.config.cps = Double(newCPS)
                        }
                    )
                    .frame(width: 26, height: 20)

                    Text("CPS")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(height: 20)

                // Increment button
                Button(action: incrementCPS) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isIncrementHovered ? Theme.textPrimary : Theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(isIncrementHovered ? Theme.surfaceHover : Color.clear)
                        .cornerRadius(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isIncrementHovered = $0 }
                .help("Hold Ctrl (±5), Alt (±10), Cmd (±50)")

                Spacer()
            }
        }
        .onAppear {
            syncCPSText()
        }
        .onChange(of: engine.config.cps) { newCPS in
            if Double(cpsInputText) != newCPS {
                syncCPSText()
            }
        }
    }

    private func syncCPSText() {
        cpsInputText = "\(Int(engine.config.cps))"
    }


    private func incrementCPS() {
        // Read directly from what is currently in the input box!
        let current = Int(cpsInputText) ?? Int(engine.config.cps)
        let step = Int(ModifierStepHelper.step(base: 1.0))
        let next = min(900, max(1, current + step))
        cpsInputText = "\(next)"
        engine.config.cps = Double(next)
    }

    private func decrementCPS() {
        // Read directly from what is currently in the input box!
        let current = Int(cpsInputText) ?? Int(engine.config.cps)
        let step = Int(ModifierStepHelper.step(base: 1.0))
        let next = max(1, min(900, current - step))
        cpsInputText = "\(next)"
        engine.config.cps = Double(next)
    }
}



