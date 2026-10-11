import SwiftUI

public struct TimerConfigSection: View {
    @ObservedObject var engine: ClickEngine

    @State private var delayText: String = ""
    @State private var durationText: String = ""
    @State private var clicksText: String = ""

    public init(engine: ClickEngine) {
        self.engine = engine
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 3) {
            // Column 1: Start after
            TimerColumnView(
                title: "Start delay",
                isEnabled: $engine.config.startDelayEnabled,
                unit: nil,
                onDecrement: decrementDelay,
                onIncrement: incrementDelay
            ) {
                NativeDecimalField(
                    text: $delayText,
                    minValue: 0.0001,
                    maxValue: 3600.0,
                    fontSize: 8.5,
                    fontWeight: .regular,
                    textColor: Theme.nsTextPrimary,
                    onChange: { engine.config.startDelaySeconds = $0 }
                )
            }

            // Column 2: Stop after
            TimerColumnView(
                title: "Duration",
                isEnabled: $engine.config.stopDurationEnabled,
                unit: nil,
                onDecrement: decrementDuration,
                onIncrement: incrementDuration
            ) {
                NativeDecimalField(
                    text: $durationText,
                    minValue: 0.0001,
                    maxValue: 86400.0,
                    fontSize: 8.5,
                    fontWeight: .regular,
                    textColor: Theme.nsTextPrimary,
                    onChange: { engine.config.stopDurationSeconds = $0 }
                )
            }

            // Column 3: clicks count
            TimerColumnView(
                title: "Max clix",
                isEnabled: $engine.config.clickLimitEnabled,
                unit: nil,
                onDecrement: decrementClicks,
                onIncrement: incrementClicks
            ) {
                NativeDigitsField(
                    text: $clicksText,
                    minValue: 1,
                    maxValue: 10_000_000,
                    fontSize: 8.5,
                    fontWeight: .regular,
                    textColor: Theme.nsTextPrimary,
                    onChange: { engine.config.clickLimit = $0 }
                )
            }
        }
        .onAppear {
            syncAllTexts()
        }
        .onChange(of: engine.config.startDelaySeconds) { newDelay in
            if Double(delayText) != newDelay {
                syncDelayText()
            }
        }
        .onChange(of: engine.config.stopDurationSeconds) { newDuration in
            if Double(durationText) != newDuration {
                syncDurationText()
            }
        }
        .onChange(of: engine.config.clickLimit) { newLimit in
            if Int(clicksText) != newLimit {
                syncClicksText()
            }
        }
    }

    // MARK: - Sync & Formatting

    private func syncAllTexts() {
        syncDelayText()
        syncDurationText()
        syncClicksText()
    }

    private func formatNumberString(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(val))"
        } else {
            let str = String(format: "%.4f", val)
            var trimmed = str
            while trimmed.hasSuffix("0") { trimmed.removeLast() }
            if trimmed.hasSuffix(".") { trimmed.removeLast() }
            return trimmed
        }
    }

    private func syncDelayText() {
        delayText = formatNumberString(engine.config.startDelaySeconds)
    }

    private func syncDurationText() {
        durationText = formatNumberString(engine.config.stopDurationSeconds)
    }

    private func syncClicksText() {
        clicksText = "\(engine.config.clickLimit)"
    }

    // MARK: - Stepper Actions

    private func incrementDelay() {
        let current = Double(delayText) ?? engine.config.startDelaySeconds
        let step = ModifierStepHelper.step(base: 1.0, isDecimal: true)
        let next = min(3600.0, current + step)
        let rounded = (round(next * 10000) / 10000)
        engine.config.startDelaySeconds = rounded
        delayText = formatNumberString(rounded)
    }

    private func decrementDelay() {
        let current = Double(delayText) ?? engine.config.startDelaySeconds
        let step = ModifierStepHelper.step(base: 1.0, isDecimal: true)
        let next = max(0.0001, current - step) // 0.1 ms minimum
        let rounded = (round(next * 10000) / 10000)
        engine.config.startDelaySeconds = rounded
        delayText = formatNumberString(rounded)
    }

    private func incrementDuration() {
        let current = Double(durationText) ?? engine.config.stopDurationSeconds
        let step = ModifierStepHelper.step(base: 1.0, isDecimal: true)
        let next = min(86400.0, current + step)
        let rounded = (round(next * 10000) / 10000)
        engine.config.stopDurationSeconds = rounded
        durationText = formatNumberString(rounded)
    }

    private func decrementDuration() {
        let current = Double(durationText) ?? engine.config.stopDurationSeconds
        let step = ModifierStepHelper.step(base: 1.0, isDecimal: true)
        let next = max(0.0001, current - step) // 0.1 ms minimum
        let rounded = (round(next * 10000) / 10000)
        engine.config.stopDurationSeconds = rounded
        durationText = formatNumberString(rounded)
    }

    private func incrementClicks() {
        let current = Int(clicksText) ?? engine.config.clickLimit
        let step = Int(ModifierStepHelper.step(base: 1.0))
        let next = min(10_000_000, max(1, current + step))
        clicksText = "\(next)"
        engine.config.clickLimit = next
    }

    private func decrementClicks() {
        let current = Int(clicksText) ?? engine.config.clickLimit
        let step = Int(ModifierStepHelper.step(base: 1.0))
        let next = max(1, current - step)
        clicksText = "\(next)"
        engine.config.clickLimit = next
    }
}

// MARK: - Column View

struct TimerColumnView<InputView: View>: View {
    let title: String
    @Binding var isEnabled: Bool
    let unit: String?
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @ViewBuilder let inputField: () -> InputView

    @State private var isLabelHovered: Bool = false
    @State private var isColumnHovered: Bool = false
    @State private var isMinusHovered: Bool = false
    @State private var isPlusHovered: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            // Label
            // When active: clickable to toggle off
            // When inactive: clicking the label or anywhere in column activates it
            Button(action: {
                isEnabled.toggle()
            }) {
                Text(title)
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundColor(isEnabled ? Theme.textPrimary : (isColumnHovered ? Theme.textPrimary : Theme.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 0)
                    .background(isEnabled && isLabelHovered ? Theme.surfaceHover : Color.clear)
                    .cornerRadius(2)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isLabelHovered = $0 }
            .disabled(!isEnabled) // If inactive, column tapGesture handles it

            // Stepper: [-] input [+]
            HStack(spacing: 0) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(isMinusHovered ? Theme.textPrimary : Theme.textSecondary)
                        .frame(width: 13, height: 18)
                        .background(isMinusHovered ? Theme.surfaceHover : Color.clear)
                        .cornerRadius(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isMinusHovered = $0 }
                .disabled(!isEnabled)

                HStack(spacing: 1) {
                    inputField()
                        .frame(maxWidth: .infinity)
                        .frame(height: 13)

                    if let unit = unit {
                        Text(unit)
                            .font(.system(size: 7.5, weight: .regular, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.trailing, 2)
                    }
                }
                .frame(height: 18)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(isPlusHovered ? Theme.textPrimary : Theme.textSecondary)
                        .frame(width: 13, height: 18)
                        .background(isPlusHovered ? Theme.surfaceHover : Color.clear)
                        .cornerRadius(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isPlusHovered = $0 }
                .disabled(!isEnabled)
            }
            .opacity(isEnabled ? 1.0 : 0.25)
            .allowsHitTesting(isEnabled)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { isColumnHovered = $0 }
        .onTapGesture {
            if !isEnabled {
                isEnabled = true
            }
        }
    }
}




