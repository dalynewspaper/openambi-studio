import SwiftUI

/// Editorial loading components for openambi 2.0.
///
/// The v1 app reached for `ProgressView()` whenever it had to wait on the
/// network — a perfectly adequate but tonally generic spinner. openambi
/// is a "private cinema for sound", so loading should *feel* like a
/// breath, a held note, a developing room — not a UIKit hourglass.
///
/// Two primitives:
/// - `AuroraLoader.Breath` — a slowly pulsing ring sigil suitable for
///   any "we're loading content" centerpiece. Replaces full-screen
///   `ProgressView()` overlays.
/// - `View.shimmer()` — a chrome-of-glass sheen that sweeps across any
///   placeholder shape. Replaces the "spinner inside an empty list" anti
///   pattern with a structural skeleton the user can read.
///
/// Both primitives respect `accessibilityReduceMotion`: the breath
/// becomes a steady glow, the shimmer becomes a static highlight.
enum AuroraLoader {

    /// Slow pulsing sigil. Looks like a held note, not a spinner.
    struct Breath: View {
        var tint: Color = .white
        var diameter: CGFloat = 56

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var animating: Bool = false

        var body: some View {
            ZStack {
                // Outer glow that pulses scale + opacity.
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: max(1, diameter * 0.05))
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(animating ? 1.25 : 0.85)
                    .opacity(animating ? 0 : 0.9)
                    .animation(
                        reduceMotion
                        ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 2.6).repeatForever(autoreverses: false),
                        value: animating
                    )

                // Inner sigil that breathes opacity.
                BrandRing(tint: tint, innerRatio: 0.55, showsInnerGroove: diameter >= 36)
                    .frame(width: diameter * 0.7, height: diameter * 0.7)
                    .opacity(animating ? 1 : 0.55)
                    .animation(
                        Motion.breath,
                        value: animating
                    )
            }
            .accessibilityElement()
            .accessibilityLabel("Loading")
            .accessibilityAddTraits(.updatesFrequently)
            .onAppear {
                animating = true
            }
        }
    }

    /// A taller, two-line block intended for full-screen modal loaders
    /// (uploads, big saves). Includes a status caption.
    struct Modal: View {
        let title: String
        let subtitle: String?
        var tint: Color = .white

        var body: some View {
            VStack(spacing: 22) {
                Breath(tint: tint, diameter: 64)

                VStack(spacing: 8) {
                    Text(title)
                        .font(AuroraTypography.editorial(18, weight: .medium))
                        .foregroundColor(AuroraColors.TextOnAurora.primary)
                        .multilineTextAlignment(.center)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AuroraTypography.ui(13))
                            .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Shimmer modifier

extension View {
    /// Sweeps a soft highlight across the receiver. Use on skeleton
    /// placeholders so loading state reads as structure forming rather
    /// than a generic wait. Static (no animation) under Reduce Motion.
    func shimmer(active: Bool = true) -> some View {
        modifier(_Shimmer(active: active))
    }
}

private struct _Shimmer: ViewModifier {
    let active: Bool

    @State private var phase: CGFloat = -1.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if active && !reduceMotion {
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.0), location: 0.30),
                                .init(color: .white.opacity(0.22), location: 0.50),
                                .init(color: .white.opacity(0.0), location: 0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geo.size.width * 1.6, height: geo.size.height)
                        .offset(x: geo.size.width * phase)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                        .onAppear {
                            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                                phase = 1.2
                            }
                        }
                    } else if active {
                        LinearGradient(
                            colors: [.white.opacity(0.10), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .allowsHitTesting(false)
                    }
                }
                .mask(content)
            )
    }
}

#if DEBUG
#Preview("AuroraLoader.Breath") {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        AuroraLoader.Breath(tint: SoundColor.rain, diameter: 80)
    }
}

#Preview("AuroraLoader.Modal") {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        AuroraLoader.Modal(
            title: "Listening for your library…",
            subtitle: "This may take a moment over a slow connection."
        )
    }
}
#endif
