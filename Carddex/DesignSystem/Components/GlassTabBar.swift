import SwiftUI

enum Tab: CaseIterable {
    case market, collection, scan, portfolio, settings
}

extension View {
    /// The native `TabView` manages content insets for the Liquid Glass tab bar,
    /// so this is now a no-op — kept so existing call sites don't need to change.
    func tabBarSafeArea() -> some View { self }
}
