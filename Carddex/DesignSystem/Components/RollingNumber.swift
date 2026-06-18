import SwiftUI

/// A number that counts up from 0 (or its previous value) to a target on appear
/// or change, with a spring. Respects Reduce Motion (snaps to final value).
/// Used for portfolio totals, collection value, market index, stat tiles — every
/// big number in the app gets the satisfying roll-up from the design spec.
struct RollingNumber: View {
    let value: Double
    /// Formats the intermediate display value into the shown string.
    var format: (Double) -> String
    var fontSize: CGFloat = 42
    var fontDesign: Font.Design = .rounded
    var fontWeight: Font.Weight = .bold
    var color: Color = Theme.textPrimary

    @State private var displayed: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ value: Double,
         format: @escaping (Double) -> String = { $0.formatted(.currency(code: "USD")) },
         size: CGFloat = 42,
         design: Font.Design = .rounded,
         weight: Font.Weight = .bold,
         color: Color = Theme.textPrimary) {
        self.value = value
        self.format = format
        self.fontSize = size
        self.fontDesign = design
        self.fontWeight = weight
        self.color = color
    }

    var body: some View {
        Text(format(displayed))
            .font(.system(size: fontSize, weight: fontWeight, design: fontDesign))
            .foregroundStyle(color)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: displayed))
            .onAppear { roll() }
            .onChange(of: value) { _, _ in roll() }
    }

    private func roll() {
        if reduceMotion {
            displayed = value
            return
        }
        displayed = 0
        withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.1)) {
            displayed = value
        }
    }
}
