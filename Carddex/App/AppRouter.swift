import SwiftUI

/// Shared navigation state so any screen can switch tabs (e.g. an empty-state
/// "Scan your first card" button jumping to the Scan tab).
@Observable
final class AppRouter {
    var selectedTab: Tab = .market
}
