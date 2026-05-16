import SwiftUI

// MARK: - Dominant sound color (environment)
//
// Soundscape3DView publishes the dominant active SoundColor here so chrome
// (AuroraGlass edges, accents, focus rings) can pick it up without each
// surface having to know about the audio engine.

private struct DominantSoundColorKey: EnvironmentKey {
    static let defaultValue: Color = SoundColor.rain
}

extension EnvironmentValues {
    var dominantSoundColor: Color {
        get { self[DominantSoundColorKey.self] }
        set { self[DominantSoundColorKey.self] = newValue }
    }
}

// MARK: - Motion vocabulary
//
// Three named curves for the entire app, all routed through Reduce Motion.
// - breath: idle ambience (orbs, fog, dock pulse) — long, calm, never bouncy.
// - touch:  direct manipulation (taps, chip activation) — quick, ~18% overshoot.
// - cinema: scene transitions (intro, "step inside") — slow, weighted easing.
//
// Replaces ad‑hoc `.spring(response: 0.5, dampingFraction: 0.8)` literals.

enum Motion {
    /// Long, eased, never bouncy. Use for idle/ambient looping animation.
    static var breath: Animation {
        if Self.prefersReducedMotion {
            return .easeInOut(duration: 5.5)
        }
        return .easeInOut(duration: 5.5)
    }

    /// Snappy spring for direct manipulation. ~18% overshoot.
    static var touch: Animation {
        if Self.prefersReducedMotion {
            return .easeOut(duration: 0.22)
        }
        return .spring(response: 0.28, dampingFraction: 0.78, blendDuration: 0)
    }

    /// Slow, weighted ease for scene-level transitions and reveals.
    /// Pair with `InstrumentFeedback.cinema()` at completion (Phase 1.3).
    static var cinema: Animation {
        if Self.prefersReducedMotion {
            return .easeOut(duration: 0.45)
        }
        return .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.85)
    }

    /// Reads UIAccessibility at call time so toggling Reduce Motion in
    /// Settings takes effect immediately without restarting the app.
    static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled || SettingsManager.shared.reduceMotion
    }
}

// MARK: - Aurora typography
//
// Two voices. Editorial for moments; system for controls.
// editorial → Kode Mono   (brand wordmark moments)
// display   → New York Light (serif) (hero numbers, place names)
// ui        → SF Pro Rounded (labels, buttons, body)
// mono      → SF Mono     (volume %, dB, time)
//
// Coexists with AppTypography (legacy). Phase 2 migrates surfaces over.

enum AuroraTypography {
    static func editorial(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("Kode Mono", size: size).weight(weight)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Canonical sizes — semantic tokens for the redesign.
    enum Size {
        static let editorialHero: CGFloat = 40
        static let editorialDisplay: CGFloat = 28
        static let editorialCaption: CGFloat = 18

        static let displayHero: CGFloat = 48     // place names, hero numbers
        static let displayTitle: CGFloat = 32

        static let uiTitle: CGFloat = 22
        static let uiHeadline: CGFloat = 17
        static let uiBody: CGFloat = 15
        static let uiCaption: CGFloat = 13

        static let monoTimer: CGFloat = 56
        static let monoVolume: CGFloat = 17
        static let monoMeta: CGFloat = 12
    }
}

// MARK: - Aurora glass
//
// One material primitive with three semantic forms. The signature feature
// is the chromatic edge — a thin gradient stroke that subtly picks up the
// dominant sound color, anchoring chrome to whatever the user is mixing.
//
// Honors:
// - SettingsManager.shared.liquidGlassEffects (off → opaque fallback)
// - @Environment(\.accessibilityReduceTransparency) (on → opaque fallback)

enum AuroraGlass {
    /// Lightest. Settings rows, library cards, list items.
    case surface
    /// Deepest. The Studio dock and primary mix controls.
    case dock
    /// Almost invisible. Modals and full‑bleed sheets that must let the
    /// scene breathe.
    case canvas

    var defaultCornerRadius: CGFloat {
        switch self {
        case .surface: return 20
        case .dock:    return 32
        case .canvas:  return 28
        }
    }

    fileprivate var baseFillOpacity: Double {
        switch self {
        case .surface: return 0.35
        case .dock:    return 0.55
        case .canvas:  return 0.18
        }
    }

    fileprivate var edgeBrightness: Double {
        switch self {
        case .surface: return 0.20
        case .dock:    return 0.32
        case .canvas:  return 0.14
        }
    }

    fileprivate var chromaticIntensity: Double {
        switch self {
        case .surface: return 0.35
        case .dock:    return 0.60
        case .canvas:  return 0.22
        }
    }

    fileprivate var shadowRadius: CGFloat {
        switch self {
        case .surface: return 14
        case .dock:    return 28
        case .canvas:  return 22
        }
    }

    fileprivate var shadowOpacity: Double {
        switch self {
        case .surface: return 0.20
        case .dock:    return 0.30
        case .canvas:  return 0.24
        }
    }
}

private struct AuroraGlassModifier: ViewModifier {
    let form: AuroraGlass
    let cornerRadius: CGFloat?

    @Environment(\.dominantSoundColor) private var dominant
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var settings = SettingsManager.shared

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? form.defaultCornerRadius

        content
            .background {
                ZStack {
                    if shouldUseTransparency {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(form.baseFillOpacity)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    } else {
                        // Reduce Transparency / Liquid Glass disabled — opaque scrim
                        // tinted slightly toward the scene's dominant color so the
                        // surface still feels alive.
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.black.opacity(0.65))
                            .overlay(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .fill(dominant.opacity(0.06))
                            )
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(edgeGradient, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(form.shadowOpacity),
                    radius: form.shadowRadius,
                    x: 0,
                    y: form.shadowRadius / 3)
    }

    private var shouldUseTransparency: Bool {
        settings.liquidGlassEffects && !reduceTransparency
    }

    /// The signature chromatic edge: a 1pt gradient stroke that picks up
    /// the dominant sound color on one diagonal, then fades to neutral
    /// white highlight on the other. Subtle but unmistakable.
    private var edgeGradient: LinearGradient {
        let chroma = dominant.opacity(form.chromaticIntensity)
        let highlight = Color.white.opacity(form.edgeBrightness)
        let trough = Color.white.opacity(0.04)
        return LinearGradient(
            colors: [chroma, highlight, trough, chroma.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    /// Apply the Aurora Glass material in a given semantic form.
    /// The chromatic edge picks up `@Environment(\.dominantSoundColor)`.
    func auroraGlass(_ form: AuroraGlass, cornerRadius: CGFloat? = nil) -> some View {
        modifier(AuroraGlassModifier(form: form, cornerRadius: cornerRadius))
    }
}

#if DEBUG
#Preview("Aurora tokens — catalog") {
    ScrollView {
        VStack(alignment: .leading, spacing: 28) {
            Group {
                Text("Typography")
                    .font(AuroraTypography.ui(13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.5)
                Text("openambi")
                    .font(AuroraTypography.editorial(AuroraTypography.Size.editorialHero))
                Text("Lisbon, Alfama")
                    .font(AuroraTypography.display(AuroraTypography.Size.displayHero))
                Text("Soundscape control surface")
                    .font(AuroraTypography.ui(AuroraTypography.Size.uiHeadline, weight: .medium))
                Text("−12.4 dB")
                    .font(AuroraTypography.mono(AuroraTypography.Size.monoVolume))
            }
            .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.15))

            Group {
                Text("Aurora glass forms")
                    .font(AuroraTypography.ui(13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.5)

                ForEach([AuroraGlass.surface, .dock, .canvas], id: \.self) { form in
                    HStack {
                        Text(label(for: form))
                            .font(AuroraTypography.ui(AuroraTypography.Size.uiHeadline, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(20)
                    .auroraGlass(form)
                }
            }
        }
        .padding(24)
    }
    .background(AppTheme.background.ignoresSafeArea())
    .environment(\.dominantSoundColor, SoundColor.rain)
}

private func label(for form: AuroraGlass) -> String {
    switch form {
    case .surface: return "AuroraGlass.surface"
    case .dock:    return "AuroraGlass.dock"
    case .canvas:  return "AuroraGlass.canvas"
    }
}

extension AuroraGlass: Hashable {}
#endif
