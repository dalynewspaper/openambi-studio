import SwiftUI

/// Cinematic intro on first app appearance (Phase 3.6 of openambi 2.0).
///
/// One-shot, two-and-a-half second sequence that opens the app like a
/// credit roll instead of a loading spinner. Three beats:
///
///   0.00 — 0.90s   The brand sigil ring draws on (progress 0 → 1)
///                  over a long ease against the dynamic background
///                  for the starting track.
///   0.95 — 1.35s   The 'openambi' wordmark fades in below the ring,
///                  using the existing Wordmark.hero size.
///   1.55 — 1.95s   The tagline 'private cinema for sound' fades in
///                  beneath the wordmark in Aurora editorial caps.
///   2.50 — 2.90s   The whole composition holds, then the parent
///                  flips `isComplete = true` to crossfade into the
///                  main UI.
///
/// VoiceOver / Reduce Motion users see the lockup statically with no
/// draw-on; the full sequence collapses to a single 0.45s fade-in
/// followed by an immediate `isComplete = true` so they aren't waiting
/// on a flourish they can't perceive.
///
/// The view name is preserved so ContentView's loading flow is
/// unchanged — only the choreography inside this file becomes
/// cinematic.
struct SimpleLoadingView: View {
    @Binding var isComplete: Bool

    @State private var ringProgress: Double = 0
    @State private var ringOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 8
    @State private var taglineOpacity: Double = 0
    @State private var startingTrackName: String = "Rain"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background — calm gradient tied to the starting track.
            // We don't push the dominant-color environment here yet
            // because nothing inside the cinematic depends on it; the
            // rest of the IA picks the color up once the main UI lands.
            DynamicLoadingBackground(trackName: startingTrackName)
                .ignoresSafeArea()

            // The lockup is centered. Each element animates in on its
            // own beat so the rhythm reads as deliberate rather than a
            // single fade.
            VStack(spacing: 22) {
                BrandRing(progress: ringProgress)
                    .frame(width: 96, height: 96)
                    .opacity(ringOpacity)
                    .accessibilityHidden(true)

                Wordmark(size: .hero)
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)

                Text("private cinema for sound")
                    .font(AuroraTypography.editorial(11, weight: .medium))
                    .kerning(2.6)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.75))
                    .opacity(taglineOpacity)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("openambi — private cinema for sound")
        }
        .onAppear {
            determineStartingTrack()
            playSequence()
        }
    }

    private func determineStartingTrack() {
        // Always Rain — calm, consistent first frame on every launch.
        startingTrackName = "Rain"
    }

    /// Run the full three-beat cinematic, or the reduced-motion
    /// fallback if the user has Reduce Motion turned on.
    private func playSequence() {
        if reduceMotion {
            ringProgress = 1
            ringOpacity = 1
            wordmarkOffset = 0
            withAnimation(.easeOut(duration: 0.45)) {
                wordmarkOpacity = 1
                taglineOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                isComplete = true
            }
            return
        }

        // Beat 1 — ring draws on (long ease, no overshoot).
        withAnimation(.easeInOut(duration: 0.9)) {
            ringOpacity = 1
            ringProgress = 1
        }

        // Beat 2 — wordmark fades up on a calm spring.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                wordmarkOpacity = 1
                wordmarkOffset = 0
            }
        }

        // Beat 3 — tagline fades in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeOut(duration: 0.4)) {
                taglineOpacity = 1
            }
        }

        // Beat 4 — hand off to the main UI. ContentView crossfades
        // showLoadingScreen → false on this signal.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            isComplete = true
        }
    }
}

// MARK: - Dynamic Loading Background (Exact Copy of Main Screen)

struct DynamicLoadingBackground: View {
    let trackName: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base: Same as main screen background (ImmersiveBackground)
                AppTheme.background
                    .ignoresSafeArea(.all)
                
                // Liquid Glass Layer 1: Content-driven color gradient
                // This exactly matches ImmersiveBackground
                AppTheme.contentGradient(for: [trackName])
                    .opacity(0.3)
                    .blendMode(.plusLighter)
                    .ignoresSafeArea(.all)
                
                // Liquid Glass Layer 2: Dynamic color wash from active sound
                // This exactly matches ImmersiveBackground (using default volume of 0.5 for loading)
                let trackColor = SoundColor.colorForTrack(trackName)
                let opacity = 0.12 * 0.5 // Default volume of 0.5 for loading screen
                trackColor
                    .opacity(opacity)
                    .blendMode(.plusLighter)
                    .ignoresSafeArea(.all)
            }
        }
        .ignoresSafeArea(.all)
    }
}

