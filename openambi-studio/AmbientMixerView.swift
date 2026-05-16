import SwiftUI

struct AmbientMixerView: View {
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var supabaseService = SupabaseService()
    @State private var presets: [Preset] = []
    @State private var isLoading = true
    
    private var tracks: [AudioTrack] {
        audioManager.tracks
    }
    
    private var activeTracks: [AudioTrack] {
        tracks.filter { $0.isActive && $0.volume > 0 }
    }
    
    var body: some View {
        ZStack {
            // Dynamic background that adapts to active sounds
            DynamicBackground(activeTracks: tracks)
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Enhanced header
                    headerSection
                    
                    // Enhanced master controls
                    EnhancedMasterControls(audioManager: audioManager)
                    
                    // Enhanced presets
                    if !presets.isEmpty {
                        presetsSection
                    }
                    
                    // Enhanced track cards
                    tracksSection
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("openambi")
                .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            activeTracks.isEmpty ? AppTheme.rainBlue : SoundColor.colorForTrack(activeTracks.first?.name ?? ""),
                            AppTheme.accent
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 10)
        }
        .padding(.vertical, 20)
    }
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Presets")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(presets) { preset in
                        EnhancedPresetCard(preset: preset) {
                            applyPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sounds")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            
        VStack(spacing: 16) {
            ForEach(audioManager.tracks.indices, id: \.self) { index in
                    EnhancedTrackCard(track: $audioManager.tracks[index], audioManager: audioManager)
                }
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            let fetchedTracks = try await supabaseService.fetchAudioTracks()
            let fetchedPresets = try await supabaseService.fetchPresets()
            
            // Add frequency tracks
            let frequencyTracks = FrequencyPresetService.shared.createFrequencyTracks()
            let allTracks = fetchedTracks + frequencyTracks
            
            await MainActor.run {
                // Only load tracks from Supabase - no fallback
                self.presets = fetchedPresets
                self.audioManager.loadTracks(allTracks)
                print("✅ Loaded \(fetchedTracks.count) tracks from Supabase + \(frequencyTracks.count) frequency tracks")
                self.isLoading = false
            }
        } catch {
            print("⚠️ Failed to load data from Supabase: \(error)")
            await MainActor.run {
                // Don't use fallback - only show tracks from Supabase
                self.audioManager.loadTracks([]) // Empty array if Supabase fails
                self.isLoading = false
            }
        }
    }
    
    private func applyPreset(_ preset: Preset) {
        audioManager.reset()
        
        for (trackName, volume) in preset.trackConfigurations {
            if let index = audioManager.tracks.firstIndex(where: { $0.name == trackName }) {
                audioManager.tracks[index].volume = volume
                audioManager.tracks[index].isActive = volume > 0
                audioManager.updateTrackVolume(audioManager.tracks[index].id, volume: volume)
                audioManager.toggleTrack(audioManager.tracks[index].id, isActive: volume > 0)
            }
        }
        
        if !preset.trackConfigurations.isEmpty {
            audioManager.play()
        }
    }
}

// MARK: - Dynamic Background
struct DynamicBackground: View {
    let activeTracks: [AudioTrack]
    
    var blendedColor: Color {
        let activeTracksFiltered = activeTracks.filter { $0.isActive && $0.volume > 0 }
        
        guard !activeTracksFiltered.isEmpty else {
            return Color(red: 0.1, green: 0.15, blue: 0.25) // Default dark
        }
        
        // Use the first active track's color, darkened for background
        // This provides a clean, predictable background color
        let firstTrackColor = SoundColor.colorForTrack(activeTracksFiltered.first?.name ?? "")
        
        // Return a darkened version of the dominant color
        // We'll use the color directly but with reduced opacity in the gradient
        return firstTrackColor
    }
    
    var body: some View {
        ZStack {
            // Base dark gradient
            let baseDark = Color(red: 0.05, green: 0.1, blue: 0.2)
                LinearGradient(
                colors: [baseDark, baseDark, baseDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Color overlay for active tracks
            let activeTracksFiltered = activeTracks.filter { $0.isActive && $0.volume > 0 }
            if !activeTracksFiltered.isEmpty {
                let activeColor = SoundColor.colorForTrack(activeTracksFiltered.first?.name ?? "")
                activeColor
                    .opacity(0.15)
                    .blendMode(.plusLighter)
            }
            
            // Animated color orbs for each active sound
            ForEach(activeTracks.filter { $0.isActive && $0.volume > 0 }, id: \.id) { track in
                let color = SoundColor.colorForTrack(track.name)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.25 * track.volume),
                                color.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 400
                        )
                    )
                    .frame(width: 800, height: 800)
                    .position(
                        x: CGFloat.random(in: 100...400),
                        y: CGFloat.random(in: 200...1000)
                    )
                    .blur(radius: 100)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3), value: blendedColor)
        }
    }

// MARK: - Enhanced Track Card
struct EnhancedTrackCard: View {
    @Binding var track: AudioTrack
    let audioManager: AudioManager
    @State private var pulseScale: CGFloat = 1.0
    
    var trackColor: Color {
        SoundColor.colorForTrack(track.name)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon with animated glow
            ZStack {
                // Pulsing glow effect when active
                Circle()
                    .fill(trackColor.opacity(0.4))
                    .frame(width: 80, height: 80)
                    .blur(radius: 15)
                    .scaleEffect(track.isActive ? pulseScale : 1.0)
                    .opacity(track.isActive ? 0.7 : 0)
                
                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: track.isActive ? 
                                        [trackColor, trackColor.opacity(0.5)] :
                                        [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: track.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        track.isActive ? 
                            trackColor : 
                            Color.white.opacity(0.5)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
            Text(track.name)
                    .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                
                // Visual volume indicator bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [trackColor, trackColor.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * track.volume, height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            // Enhanced volume slider with color
            VStack(spacing: 8) {
            Slider(value: Binding(
                get: { track.volume },
                set: { newValue in
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        
                    track.volume = newValue
                    audioManager.updateTrackVolume(track.id, volume: newValue)
                    if newValue > 0 && !track.isActive {
                        track.isActive = true
                        audioManager.toggleTrack(track.id, isActive: true)
                    } else if newValue == 0 && track.isActive {
                        track.isActive = false
                        audioManager.toggleTrack(track.id, isActive: false)
                    }
                }
            ), in: 0...1)
                .tint(trackColor)
                .frame(width: 150)
            
                Text("\(Int(track.volume * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(trackColor.opacity(0.9))
            }
        }
        .padding(24)
        .glassCard(color: trackColor, intensity: track.volume, isActive: track.isActive)
        .onAppear {
            if track.isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            }
        }
        .onChange(of: track.isActive) { _, isActive in
            if isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            } else {
                withAnimation {
                    pulseScale = 1.0
                }
            }
        }
    }
}

// MARK: - Enhanced Preset Card
struct EnhancedPresetCard: View {
    let preset: Preset
    let action: () -> Void
    @State private var isPressed = false
    
    // Calculate dominant color from preset's tracks
    var dominantColor: Color {
        // Get first track color as dominant
        if let firstTrack = preset.trackConfigurations.keys.first {
            return SoundColor.colorForTrack(firstTrack)
        }
        return AppTheme.rainBlue
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: 16) {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(dominantColor.opacity(0.4))
                        .frame(width: 90, height: 90)
                        .blur(radius: 20)
                    
                    // Glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
        .overlay(
                            Circle()
                .stroke(
                                    LinearGradient(
                                        colors: [dominantColor, dominantColor.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(dominantColor)
                }
                
                VStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(preset.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(width: 160, height: 200)
            .padding(24)
            .glassCard(color: dominantColor, intensity: 0.6, isActive: true)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Enhanced Master Controls
struct EnhancedMasterControls: View {
    @ObservedObject var audioManager: AudioManager
    @State private var rotationAngle: Double = 0
    
    // Blend colors from active tracks
    var activeColor: Color {
        let activeTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
        guard !activeTracks.isEmpty else { return AppTheme.rainBlue }
        
        // Use first active track's color
        return SoundColor.colorForTrack(activeTracks.first?.name ?? "")
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Enhanced play/pause button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
                
                if audioManager.isPlaying {
                    audioManager.pause()
                } else {
                    audioManager.play()
                }
            } label: {
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    activeColor.opacity(0.6),
                                    activeColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(rotationAngle))
                        .blur(radius: 8)
                    
                    // Glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: audioManager.isPlaying ? 
                                            [activeColor, activeColor.opacity(0.5)] :
                                            [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                )
        )
                        .frame(width: 130, height: 130)
                        .shadow(color: activeColor.opacity(0.5), radius: 30, x: 0, y: 15)
                    
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 45, weight: .light))
                        .foregroundStyle(activeColor)
                }
            }
            .onAppear {
                if audioManager.isPlaying {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            }
            .onChange(of: audioManager.isPlaying) { _, isPlaying in
                if isPlaying {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                } else {
                    withAnimation {
                        rotationAngle = 0
                    }
                }
            }
            
            // Enhanced volume slider
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(activeColor.opacity(0.9))
                    
                    Slider(value: $audioManager.masterVolume, in: 0...1)
                        .tint(
                            LinearGradient(
                                colors: [activeColor, activeColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .onChange(of: audioManager.masterVolume) { _, newValue in
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            audioManager.updateMasterVolume(newValue)
                        }
                    
                    Text("\(Int(audioManager.masterVolume * 100))")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(activeColor)
                        .frame(width: 50)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(40)
        .glassCard(color: activeColor, intensity: 0.4, isActive: audioManager.isPlaying)
    }
}

#Preview {
    AmbientMixerView()
        .environmentObject(AudioManager())
}
