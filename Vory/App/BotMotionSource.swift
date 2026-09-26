import CoreMotion
import SwiftUI
import VoryCore

/// Feeds `BotAmbient.shared.tilt` from the device's attitude while the app is in front and the
/// Settings › Bots switch is on. The resting hold (the attitude when the source starts, then
/// slowly re-centred) counts as level, so a phone held at any angle shows upright bots.
@MainActor
final class BotMotionSource {
    static let shared = BotMotionSource()
    static let enabledKey = "bots.motion"

    private let manager = CMMotionManager()
    private var restRoll = 0.0, restPitch = 0.0
    private var haveRest = false

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey); apply() }
    }

    /// Starts or stops with the setting and the scene phase.
    func apply(active: Bool = true) {
        BotAmbient.shared.enabled = enabled
        guard enabled, active, manager.isDeviceMotionAvailable, !UIAccessibility.isReduceMotionEnabled else {
            manager.stopDeviceMotionUpdates()
            BotAmbient.shared.tilt = .zero
            haveRest = false
            return
        }
        guard !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let a = motion?.attitude else { return }
            if !haveRest { restRoll = a.roll; restPitch = a.pitch; haveRest = true }
            // The rest drifts toward the current hold, so a new posture becomes the new level.
            restRoll += (a.roll - restRoll) * 0.01
            restPitch += (a.pitch - restPitch) * 0.01
            let x = max(-1, min(1, (a.roll - restRoll) / 0.45))
            let y = max(-1, min(1, (a.pitch - restPitch) / 0.45))
            let t = BotAmbient.shared.tilt
            // Smoothed a little so the lean is calm, not jittery.
            BotAmbient.shared.tilt = CGPoint(x: t.x + (x - t.x) * 0.25, y: t.y + (y - t.y) * 0.25)
        }
    }
}
