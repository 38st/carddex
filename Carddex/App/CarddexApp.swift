import SwiftUI

@main
struct CarddexApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var store = CollectionStore(items: SampleData.collection)
    @State private var environment = AppEnvironment()
    @State private var subscriptions = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(environment)
                .environment(subscriptions)
                .fullScreenCover(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { presented in if !presented { hasOnboarded = true } }
                )) {
                    OnboardingView()
                }
        }
    }
}
