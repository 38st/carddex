import SwiftUI

/// Composition root for services. Views depend on this rather than concrete
/// types, so the cloud provider is swappable and previews/tests use fakes.
///
/// Picks the live identification service automatically when `Secrets.plist` is
/// present (see `AppConfig`); otherwise falls back to the fake.
@Observable
final class AppEnvironment {
    let identification: any IdentificationService
    let isLiveBackend: Bool

    init() {
        if let config = AppConfig.supabase {
            self.identification = LiveIdentificationService(endpoint: config.identifyURL)
            self.isLiveBackend = true
        } else {
            self.identification = FakeIdentificationService()
            self.isLiveBackend = false
        }
    }

    /// For previews and tests.
    init(identification: any IdentificationService) {
        self.identification = identification
        self.isLiveBackend = false
    }
}
