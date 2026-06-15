import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScanView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.grid.2x2") }
            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(CollectionStore(items: SampleData.collection))
}
