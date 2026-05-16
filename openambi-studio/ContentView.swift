import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var hasAppeared = false
    @State private var showLoadingScreen = true
    @State private var loadingComplete = false
    @State private var selectedTab = Room.studio.rawValue // Start at Studio (main)
    
    var body: some View {
        ZStack {
            // Base background - always extends fully to all safe areas
            AppTheme.background
                .ignoresSafeArea(.all)
            
            Group {
                if showLoadingScreen && !loadingComplete {
                    // Simple loading screen with glassmorphism
                    SimpleLoadingView(isComplete: $loadingComplete)
                        .transition(.opacity)
                } else {
                    if hasAppeared {
                        // Horizontal swipeable TabView mapped to the three
                        // openambi rooms (Phase 2 IA). The system page dots
                        // were already hidden — the chromatic PageRail
                        // overlay below provides a quieter, brand-aware
                        // indicator that picks up the active sound color.
                        // Index 0: Field    (swipe right from main)
                        // Index 1: Studio   (default)
                        // Index 2: Atelier  (swipe left from main)
                        ZStack(alignment: .bottom) {
                            TabView(selection: $selectedTab) {
                                RecordingView(selectedTab: $selectedTab)
                                    .tag(Room.field.rawValue)
                                    .ignoresSafeArea(.all)

                                Soundscape3DView(selectedTab: $selectedTab)
                                    .tag(Room.studio.rawValue)
                                    .ignoresSafeArea(.all)

                                SettingsView()
                                    .tag(Room.atelier.rawValue)
                                    .ignoresSafeArea(.all)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .indexViewStyle(.page(backgroundDisplayMode: .never))

                            PageRail(selectedIndex: $selectedTab)
                                .padding(.bottom, 18)
                        }
                        // The dominant sound color (Phase 3.3) is the
                        // loudest active track's brand color, animated
                        // via a long Motion.breath ease so swapping the
                        // mix doesn't snap chrome between tints. Every
                        // descendant — PageRail, AuroraGlass edges, the
                        // Studio header glow — picks this up via
                        // @Environment(\.dominantSoundColor).
                        .environment(\.dominantSoundColor, dominantSoundColor)
                        .animation(Motion.breath, value: dominantSoundColor)
                        .transition(.opacity)
                    } else {
                        // Show same background as loading screen during transition
                        // This ensures seamless visual continuity
                        DynamicLoadingBackground(trackName: getStartingTrackName())
                            .ignoresSafeArea(.all)
                    }
                }
            }
        }
        .ignoresSafeArea(.all)
        .onChange(of: loadingComplete) { _, isComplete in
            if isComplete {
                // Smooth transition: fade out loading screen, fade in main UI
                withAnimation(.easeOut(duration: 0.4)) {
                    showLoadingScreen = false
                }
                
                // Show main view immediately (no intermediate white screen)
                // The Soundscape3DView will handle its own background
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        hasAppeared = true
                    }
                }
            }
        }
        .onAppear {
            // Only show loading screen on first appearance
            // If loading is skipped or completed, proceed directly
            if !showLoadingScreen || loadingComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasAppeared = true
                }
            }
        }
    }
    
    // Determine which track will start playing
    private func getStartingTrackName() -> String {
        // Always use Rain track - ensures consistent, calm experience on launch
        return "Rain"
    }

    /// The currently dominant sound color across the live mix (Phase 3.3).
    ///
    /// Algorithm: take the loudest active track. If nothing is active, fall
    /// back to `SoundColor.rain` so chrome has a calm default. Volume is the
    /// only weight — for the user, the loudest sound *is* the dominant one;
    /// this matches what they hear without us having to do perceptual
    /// blending across multiple tints (which would just produce mud).
    ///
    /// This intentionally lives in ContentView rather than the Studio so
    /// the Field room and the Atelier also receive the color. The Studio's
    /// active mix is the "what the room sounds like right now" signal for
    /// the entire app.
    private var dominantSoundColor: Color {
        let active = audioManager.tracks
            .filter { $0.isActive && $0.volume > 0.01 }
            .sorted { $0.volume > $1.volume }
        guard let loudest = active.first else {
            return SoundColor.rain
        }
        return SoundColor.colorForTrack(loudest.name)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioManager())
}
