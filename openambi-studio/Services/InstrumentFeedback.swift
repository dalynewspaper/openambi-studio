import UIKit

/// Intent-based haptic API for openambi.
///
/// Replaces scattered `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator`
/// instantiation across the app with semantic intents. Every call routes through
/// `SettingsManager.shared.hapticsOnTap`, so toggling haptics off in Settings
/// silences every surface at once.
///
/// Prefer the semantic methods (`.tap()`, `.toggle(active:)`, `.threshold(at:)`,
/// `.preset(applied:)`, `.cinema()`, etc.) at call sites. The `.impact(_:)` shim
/// exists for ambiguous legacy call sites and should be replaced over time.
enum InstrumentFeedback {

    // MARK: - Configuration

    private static var isEnabled: Bool {
        SettingsManager.shared.hapticsOnTap
    }

    // MARK: - Semantic intents

    /// A single light impression. Tapping a chip, picking an icon, confirming
    /// a small choice. The "I noticed you" haptic.
    static func tap() {
        impact(.light)
    }

    /// Toggling a track or feature on/off. Medium when activating (warmer,
    /// more decisive), light when deactivating.
    static func toggle(active: Bool) {
        impact(active ? .medium : .light)
    }

    /// User soloed a sound (or any "one of many" emphasized selection).
    /// Two quick light ticks.
    static func solo(active: Bool) {
        guard active else {
            impact(.light)
            return
        }
        impact(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            impact(.medium)
        }
    }

    /// A milestone passed while scrubbing or rotating (volume dial, sliders).
    /// `.minor` for in-between ticks, `.major` for end stops / quartiles.
    enum ThresholdPosition { case minor, major }

    static func threshold(at position: ThresholdPosition) {
        switch position {
        case .minor: impact(.light)
        case .major: impact(.medium)
        }
    }

    /// User started dragging a tile, orb, or other object out of its rest position.
    static func dragStart() {
        impact(.light)
    }

    /// User released a drag in a meaningful target zone.
    static func dragEnd() {
        impact(.medium)
    }

    /// A preset / saved scene was applied. The "this moment matters" haptic —
    /// a heavy impact followed by a selection click.
    static func preset(applied name: String) {
        _ = name
        impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selection()
        }
    }

    /// Lock-step with `Motion.cinema` — used at scene transitions and the
    /// cinematic intro reveal. A single heavy beat with a soft selection tail.
    static func cinema() {
        impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            selection()
        }
    }

    /// Discrete selection click (segmented controls, picker steps).
    static func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Notification family

    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func failure() { notify(.error) }

    // MARK: - Escape hatch
    //
    // Call sites whose semantic intent isn't yet clear can use this — it still
    // respects `hapticsOnTap` and centralizes generator instantiation.

    enum ImpactStyle { case light, medium, heavy, soft, rigid }

    static func impact(_ style: ImpactStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style.uikit)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Internals

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

private extension InstrumentFeedback.ImpactStyle {
    var uikit: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:  return .light
        case .medium: return .medium
        case .heavy:  return .heavy
        case .soft:   return .soft
        case .rigid:  return .rigid
        }
    }
}
