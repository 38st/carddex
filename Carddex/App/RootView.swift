import SwiftUI

struct RootView: View {
    @State private var selection: Tab = .scan

    var body: some View {
        ZStack(alignment: .bottom) {
            VaultBackground()

            Group {
                switch selection {
                case .scan: ScanView()
                case .collection: CollectionView()
                case .portfolio: PortfolioView()
                case .settings: SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }

            GlassTabBar(selection: $selection)
                .padding(.bottom, 4)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment())
        .environment(SubscriptionStore())
}
