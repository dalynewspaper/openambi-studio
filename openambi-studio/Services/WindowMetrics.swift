import SwiftUI
import UIKit

/// Reads true safe-area insets from the key window.
///
/// Why this exists
/// ----------------
/// `ContentView` and every top-level room (`Soundscape3DView`,
/// `RecordingView`, `SettingsView`) call `.ignoresSafeArea(.all)` so the
/// AuroraGlass / DynamicLoadingBackground washes bleed edge to edge.
/// A side effect: any `GeometryReader` placed inside that chain reports
/// `safeAreaInsets == .zero`, which collapses our editorial headers
/// against the Dynamic Island / status bar.
///
/// `WindowMetrics` reads insets straight from the active `UIWindowScene`
/// so layout code can always recover the device's real status-bar /
/// home-indicator chrome regardless of what its ancestors have done.
///
/// Usage
/// -----
///     let topInset = max(geometry.safeAreaInsets.top,
///                        WindowMetrics.safeAreaInsets.top)
///
/// The `max(...)` pattern is deliberate: in environments where SwiftUI
/// already reports a valid inset (e.g. previews, embedded sheets) we
/// honor it; we only fall back to the window when SwiftUI reports zero.
enum WindowMetrics {

    /// Safe-area insets of the key window of the foreground-active scene.
    /// Returns `.zero` if no key window is found (very early startup,
    /// SwiftUI previews); callers should `max(...)` against a sensible
    /// fallback when that matters.
    static var safeAreaInsets: UIEdgeInsets {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first

        guard let scene = activeScene else { return .zero }
        let keyWindow = scene.windows.first(where: { $0.isKeyWindow })
            ?? scene.windows.first
        return keyWindow?.safeAreaInsets ?? .zero
    }

    /// Convenience for the most common consumer (the editorial headers).
    static var topInset: CGFloat { safeAreaInsets.top }

    /// Convenience for bottom chrome (the dock + PageRail).
    static var bottomInset: CGFloat { safeAreaInsets.bottom }
}
