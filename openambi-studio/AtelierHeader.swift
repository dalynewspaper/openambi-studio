import SwiftUI

/// Top-of-Atelier editorial header.
///
/// Parity with the Field and Studio room headers (Phase 2.6 + 3.1):
///
///     ATELIER
///     A few things, your way
///
/// The trailing slot is intentionally empty — the Atelier doesn't carry
/// a place chip the way Field/Studio do, because this room is *yours*,
/// not the world outside. The space stays open as a quiet visual rest.
///
/// Accessibility: header is a single combined element so VoiceOver reads
/// "Atelier. A few things, your way." rather than two separate lines.
struct AtelierHeader: View {

    let isAuthenticated: Bool

    @Environment(\.dominantSoundColor) private var dominant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    // Same "now playing" pip as the Studio header so the
                    // user knows the live mix is still running while they
                    // poke around in here.
                    Circle()
                        .fill(dominant)
                        .frame(width: 5, height: 5)
                        .opacity(reduceMotion ? 0.78 : (pulse ? 0.85 : 0.45))
                        .accessibilityHidden(true)

                    Text("Atelier")
                        .font(AuroraTypography.editorial(11, weight: .medium))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }

                Text(subtitle)
                    .font(AuroraTypography.editorial(15, weight: .semibold))
                    .foregroundColor(AuroraColors.TextOnAurora.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 18)
        .onAppear { startBreathLoopIfNeeded() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Atelier. \(subtitle).")
    }

    /// The mood line is intentionally not a settings count or version —
    /// it's the room's voice. Slightly different copy when signed in vs
    /// signed out so the room acknowledges the user.
    private var subtitle: String {
        isAuthenticated ? "A few things, your way" : "Make this room yours"
    }

    private func startBreathLoopIfNeeded() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        VStack(spacing: 32) {
            AtelierHeader(isAuthenticated: true)
            AtelierHeader(isAuthenticated: false)
            Spacer()
        }
        .padding(.top, 60)
    }
    .environment(\.dominantSoundColor, SoundColor.rain)
}
#endif
