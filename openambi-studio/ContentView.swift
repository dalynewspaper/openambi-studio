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
}

#Preview {
    ContentView()
        .environmentObject(AudioManager())
}
