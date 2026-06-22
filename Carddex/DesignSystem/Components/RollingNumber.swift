import SwiftUI

/// A big, formatted number for portfolio totals, collection value, the market
/// index, and stat tiles. Renders statically (the count-up / odometer animation
/// was removed — values just show their final amount).
struct RollingNumber: View {
    let value: Double
    /// Formats the value into the shown string.
    var format: (Double) -> String
    var fontSize: CGFloat = 42
    var fontDesign: Font.Design = .rounded
    var fontWeight: Font.Weight = .bold
    var color: Color = Theme.textPrimary

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
        Text(format(value))
            .font(.system(size: fontSize, weight: fontWeight, design: fontDesign))
            .foregroundStyle(color)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
