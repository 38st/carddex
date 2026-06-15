import SwiftUI
import CoreMotion

/// Publishes device tilt for the holographic-foil / 3D-card effects.
/// No-ops in the simulator (device motion is unavailable), so the foil falls
/// back to its time-based animation.
@Observable
final class MotionManager {
    var roll: Double = 0
    var pitch: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            self.roll = attitude.roll
            self.pitch = attitude.pitch
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
