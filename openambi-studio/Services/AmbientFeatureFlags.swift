import Foundation
import SwiftUI

/// Central toggles for ambient-scene features. One place to disable
/// expensive visual layers when battery, accessibility, or performance
/// constraints kick in.
///
/// - Particles, waves, parallax, video, and the future time-of-day
///   tint (Phase 4) all check here before rendering. New scene features
///   added in later phases should plumb their feature flag through here
///   rather than reading `ProcessInfo` / `SettingsManager` directly.
/// - Observed so views can react to Low Power Mode changes at runtime.
final class AmbientFeatureFlags: ObservableObject {

    static let shared = AmbientFeatureFlags()

    /// Mirrors `ProcessInfo.processInfo.isLowPowerModeEnabled`. Published
    /// so views animate down gracefully when the user enables Low Power
    /// without restarting the app.
    @Published private(set) var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Resolved capability flags
    //
    // Every ambient layer checks these instead of inspecting individual
    // sources. Order of precedence: Low Power overrides everything;
    // SettingsManager liquidGlassEffects shapes texture density; the
    // accessibilityReduceMotion environment is read at each callsite
    // because it is environment-scoped, not global state.

    var allowAmbientParticles: Bool {
        !isLowPowerMode
    }

    var allowAmbientWaves: Bool {
        !isLowPowerMode
    }

    var allowFloatingColorOrbs: Bool {
        !isLowPowerMode
    }

    /// Reserved for Phase 4: gyro parallax on the Studio scene.
    var allowParallax: Bool {
        !isLowPowerMode
    }

    /// Reserved for Phase 4: warm/cool tint that tracks local time of day.
    var allowTimeOfDayTint: Bool {
        !isLowPowerMode
    }

    /// Background video playback. Soundscape3DView reads this when a user
    /// recording has a `videoUrl`. We disable it in Low Power because
    /// AVPlayer is far more expensive than the gradient fallback.
    var allowBackgroundVideo: Bool {
        !isLowPowerMode
    }

    /// Coarse density tier for layered backgrounds. Higher tiers may
    /// spawn more particles or longer trails.
    enum Density { case compact, standard, lush }

    var sceneDensity: Density {
        if isLowPowerMode { return .compact }
        return SettingsManager.shared.liquidGlassEffects ? .lush : .standard
    }

    @objc private func powerStateChanged() {
        let newValue = ProcessInfo.processInfo.isLowPowerModeEnabled
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isLowPowerMode != newValue {
                self.isLowPowerMode = newValue
            }
        }
    }
}
