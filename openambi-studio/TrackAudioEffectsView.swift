import SwiftUI

// MARK: - Track Audio Effects View
// Advanced per-track audio controls: spatial positioning, EQ, reverb

struct TrackAudioEffectsView: View {
    @Binding var track: AudioTrack
    @ObservedObject var audioManager: AudioManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var spatialX: Float = 0
    @State private var spatialY: Float = 0
    @State private var reverbAmount: Float = 0
    @State private var eqLow: Float = 0
    @State private var eqMid: Float = 0
    @State private var eqHigh: Float = 0
    @State private var advancedEnabled: Bool = false
    @State private var showNormalizeConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - consistent with app theme
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Engine toggle
                        engineToggleSection
                        
                        if advancedEnabled {
                            // Spatial positioning
                            spatialSection
                            
                            // EQ section
                            eqSection
                            
                            // Reverb section
                            reverbSection
                            
                            // Loudness normalization
                            normalizeSection
                        }
                    }
                    .padding(20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: advancedEnabled)
                }
            }
            .navigationTitle("Audio Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .onAppear {
            loadTrackSettings()
        }
    }
    
    // MARK: - Engine Toggle
    
    private var engineToggleSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Advanced Audio Engine")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Spatial audio, EQ, reverb & crossfade looping")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                Spacer()
                
                    Toggle("", isOn: $advancedEnabled)
                    .labelsHidden()
                    .tint(SoundColor.rain)
                    .onChange(of: advancedEnabled) { _, newValue in
                        audioManager.setAdvancedRendering(trackId: track.id, enabled: newValue)
                        track.useAdvancedRendering = newValue
                    }
            }
            .padding(16)
            .liquidGlass(intensity: 0.7, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
        }
    }
    
    // MARK: - Spatial Positioning
    
    private var spatialSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Spatial Position", systemImage: "speaker.wave.3.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
            
            // 2D Pad for spatial positioning
            SpatialPadView(x: $spatialX, y: $spatialY)
                .frame(height: 200)
                .onChange(of: spatialX) { _, newX in
                    audioManager.setSpatialPosition(trackId: track.id, x: newX, y: spatialY)
                    track.spatialX = newX
                }
                .onChange(of: spatialY) { _, newY in
                    audioManager.setSpatialPosition(trackId: track.id, x: spatialX, y: newY)
                    track.spatialY = newY
                }
            
            HStack {
                Text("L")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("Center")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("R")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .liquidGlass(intensity: 0.7, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
    }
    
    // MARK: - EQ Section
    
    private var eqSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Equalizer", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
            
            HStack(spacing: 20) {
                EQBandSlider(label: "Low", value: $eqLow, color: SoundColor.rain)
                    .onChange(of: eqLow) { _, _ in applyEQ() }
                
                EQBandSlider(label: "Mid", value: $eqMid, color: SoundColor.birds)
                    .onChange(of: eqMid) { _, _ in applyEQ() }
                
                EQBandSlider(label: "High", value: $eqHigh, color: SoundColor.fireplace)
                    .onChange(of: eqHigh) { _, _ in applyEQ() }
            }
            .frame(height: 160)
            
            // Reset button
            Button(action: resetEQ) {
                Text("Reset EQ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(16)
        .liquidGlass(intensity: 0.7, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
    }
    
    // MARK: - Reverb Section
    
    private var reverbSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Reverb", systemImage: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Dry")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Slider(value: $reverbAmount, in: 0...1, step: 0.01)
                        .tint(SoundColor.thunder)
                        .onChange(of: reverbAmount) { _, newValue in
                            audioManager.setTrackReverb(trackId: track.id, mix: newValue)
                            track.reverbMix = newValue
                        }
                    
                    Text("Wet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Text("\(Int(reverbAmount * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(SoundColor.thunder)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .liquidGlass(intensity: 0.7, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
    }
    
    // MARK: - Normalize Section
    
    private var normalizeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Loudness", systemImage: "waveform.badge.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
            
            Button(action: {
                audioManager.normalizeLoudness(trackId: track.id)
                showNormalizeConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showNormalizeConfirmation = false
                }
            }) {
                HStack {
                    Image(systemName: "waveform.badge.magnifyingglass")
                    Text("Balance Volume")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            
            if showNormalizeConfirmation {
                Text("Volume balanced")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            Text("Normalizes to -14 LUFS for a balanced mix across all tracks")
                .font(.system(size: 11))
                .foregroundColor(AppColors.quaternaryText)
        }
        .padding(16)
        .liquidGlass(intensity: 0.7, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
    }
    
    // MARK: - Helpers
    
    private func loadTrackSettings() {
        spatialX = track.spatialX
        spatialY = track.spatialY
        reverbAmount = track.reverbMix
        eqLow = track.eqLowGain
        eqMid = track.eqMidGain
        eqHigh = track.eqHighGain
        advancedEnabled = track.useAdvancedRendering
    }
    
    private func applyEQ() {
        audioManager.setTrackEQ(trackId: track.id, low: eqLow, mid: eqMid, high: eqHigh)
        track.eqLowGain = eqLow
        track.eqMidGain = eqMid
        track.eqHighGain = eqHigh
    }
    
    private func resetEQ() {
        eqLow = 0
        eqMid = 0
        eqHigh = 0
        applyEQ()
    }
}

// MARK: - Spatial Pad View

struct SpatialPadView: View {
    @Binding var x: Float
    @Binding var y: Float
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            
            ZStack {
                // Background grid
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                
                // Grid lines
                Path { path in
                    // Horizontal center
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    // Vertical center
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                
                // Concentric circles
                ForEach([0.25, 0.5, 0.75], id: \.self) { radius in
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(
                            width: size.width * CGFloat(radius),
                            height: size.height * CGFloat(radius)
                        )
                }
                
                // Position indicator
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SoundColor.rain,
                                SoundColor.rain.opacity(0.3)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 20
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: SoundColor.rain.opacity(0.5), radius: 12)
                    .position(
                        x: CGFloat((x + 1) / 2) * size.width,
                        y: CGFloat((1 - (y + 1) / 2)) * size.height
                    )
                
                // Listener icon at center
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .position(x: size.width / 2, y: size.height / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newX = Float(value.location.x / size.width) * 2 - 1
                        let newY = 1 - Float(value.location.y / size.height) * 2
                        x = max(-1, min(1, newX))
                        y = max(-1, min(1, newY))
                    }
            )
        }
    }
}

// MARK: - EQ Band Slider

struct EQBandSlider: View {
    let label: String
    @Binding var value: Float
    let color: Color
    
    private let range: ClosedRange<Float> = -12...12
    
    var body: some View {
        VStack(spacing: 8) {
            Text(String(format: "%+.0f", value))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            
            GeometryReader { geometry in
                let height = geometry.size.height
                let normalizedValue = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let yPos = height * (1 - normalizedValue)
                
                ZStack {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 6)
                    
                    // Center mark
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 16, height: 1)
                        .offset(y: 0)
                    
                    // Fill from center
                    let centerY = height / 2
                    let fillHeight = abs(yPos - centerY)
                    let fillOffset = value > 0
                        ? centerY - fillHeight / 2 - height / 2
                        : centerY + fillHeight / 2 - height / 2
                    
                    Capsule()
                        .fill(color.opacity(0.4))
                        .frame(width: 6, height: fillHeight)
                        .offset(y: fillOffset)
                    
                    // Thumb
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .shadow(color: color.opacity(0.4), radius: 6)
                        .offset(y: yPos - height / 2)
                }
                .frame(maxWidth: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let normalized = 1 - Float(drag.location.y / height)
                            let clamped = max(0, min(1, normalized))
                            value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        }
                )
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
