import SwiftUI

/// Card Ladder-style segmented time-range selector (1W/1M/3M/1Y/All).
/// Drives index and price charts across the app.
struct RangeSelector: View {
    @Binding var selection: IndexRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IndexRange.allCases) { range in
                let selected = selection == range
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.25)) { selection = range }
                } label: {
                    Text(range.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(selected ? .white : Theme.textSecondary)
                        .background { if selected { Capsule().fill(Theme.cream) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}
