import SwiftUI

public struct ClickConfigSection: View {
    @ObservedObject var engine: ClickEngine
    @State private var cpsInputText: String = ""
    @State private var isDecrementHovered: Bool = false
    @State private var isIncrementHovered: Bool = false

    public init(engine: ClickEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 1) {
            // Increment button (+) on top
            Button(action: incrementCPS) {
                Image(systemName: "plus")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(isIncrementHovered ? Theme.textPrimary : Theme.textSecondary)
                    .frame(width: 28, height: 11)
                    .background(isIncrementHovered ? Theme.surfaceHover : Color.clear)
                    .cornerRadius(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isIncrementHovered = $0 }
            .help("Hold Ctrl (±5), Alt (±10), Cmd (±50)")

            // Manual Input Box - Only [0-9], validated on the fly
            NativeDigitsField(
                text: $cpsInputText,
                minValue: 1,
                maxValue: 900,
                fontSize: 15.5,
                fontWeight: .semibold,
                alignment: .center,
                textColor: Theme.nsTextPrimary,
                onChange: { newCPS in
                    engine.config.cps = Double(newCPS)
                }
            )
            .frame(width: 32, height: 18)

            // Decrement button (-) on bottom
            Button(action: decrementCPS) {
                Image(systemName: "minus")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(isDecrementHovered ? Theme.textPrimary : Theme.textSecondary)
                    .frame(width: 28, height: 11)
                    .background(isDecrementHovered ? Theme.surfaceHover : Color.clear)
                    .cornerRadius(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isDecrementHovered = $0 }
            .help("Hold Ctrl (±5), Alt (±10), Cmd (±50)")
        }
        .frame(width: 32, height: 40)
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



