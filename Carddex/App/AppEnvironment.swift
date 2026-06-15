import SwiftUI

/// Composition root for services. Views depend on this rather than concrete
/// types, so the cloud provider is swappable and previews/tests use fakes.
@Observable
final class AppEnvironment {
    let identification: any IdentificationService

    init(identification: any IdentificationService = FakeIdentificationService()) {
        self.identification = identification
    }
}
