import SwiftUI

/// Simple, elegant loading screen with glassmorphism design
struct SimpleLoadingView: View {
    @Binding var isComplete: Bool
    
    // Loading state
    @State private var textOpacity: Double = 0
    @State private var startingTrackName: String = "Rain" // Default to Rain
    
    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            // Background matching main screen - based on track that will play
            DynamicLoadingBackground(trackName: startingTrackName)
                .ignoresSafeArea()
            
            // "openambi" text
            Text("openambi")
                .font(.custom("Kode Mono", size: 40))
                .foregroundColor(.white)
                .kerning(2.5)
                .opacity(textOpacity)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
        }
        .onAppear {
            determineStartingTrack()
            fadeInText()
            // Complete after a brief display time
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isComplete = true
            }
        }
    }
    
    private func determineStartingTrack() {
        // Always use Rain track - ensures consistent, calm experience on launch
        startingTrackName = "Rain"
    }
    
    private func fadeInText() {
        let duration = reduceMotion ? 0.0 : 0.3
        withAnimation(.easeOut(duration: duration)) {
            textOpacity = 1.0
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

