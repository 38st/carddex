import UIKit

/// Minimal app delegate, adapted into the SwiftUI `App`, solely to receive the
/// APNs device-token callbacks (which have no SwiftUI equivalent). The token is
/// handed to `PushRegistrationCenter`; `CarddexApp` uploads it to the backend.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in PushRegistrationCenter.shared.deviceTokenHex = hex }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Remote push simply won't arrive; the in-app local-notification path
        // (NotificationService) still covers foreground/active checks.
        NSLog("APNs registration failed: \(error.localizedDescription)")
    }
}
