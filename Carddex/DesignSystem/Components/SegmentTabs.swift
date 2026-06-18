import SwiftUI

/// Text-tab segmented control over a cream pill. Replaces the native
/// `.pickerStyle(.segmented)` and styles detail-screen section tabs.
struct SegmentTabs<T: Hashable>: View {
    @Binding var selection: T
    let items: [(value: T, label: String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.value) { item in
                let selected = selection == item.value
                Button {
                    Haptics.selection()
                    withAnimation(Theme.springTap) { selection = item.value }
                } label: {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Theme.onCream : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected { Capsule().fill(Theme.cream) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCapsule()
    }
}

#Preview {
    struct Demo: View {
        @State var sel = "Grid"
        var body: some View {
            SegmentTabs(selection: $sel, items: [("Grid", "Grid"), ("Sets", "Sets")])
                .padding()
                .background(VaultBackground())
        }
    }
    return Demo()
}
