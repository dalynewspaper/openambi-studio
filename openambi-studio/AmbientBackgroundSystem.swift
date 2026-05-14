import SwiftUI
import Combine

// MARK: - Phase 2: Ambient Background System Components

// MARK: - Noise Texture View
/// Subtle noise texture overlay for depth (0.5-1% opacity)
struct NoiseTextureView: View {
    let opacity: Double
    
    init(opacity: Double = 0.008) {
        self.opacity = opacity
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Generate subtle noise pattern
                for _ in 0..<Int(size.width * size.height * 0.001) {
                    let x = Double.random(in: 0...size.width)
                    let y = Double.random(in: 0...size.height)
                    let pointSize = Double.random(in: 0.5...2.0)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - pointSize,
                            y: y - pointSize,
                            width: pointSize * 2,
                            height: pointSize * 2
                        )),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .ignoresSafeArea(.all)
        .blendMode(.overlay)
    }
}

// MARK: - Enhanced Particle System
/// Particle system with 3-5 floating orbs per active track
struct AmbientParticleSystem: View {
    let tracks: [AudioTrack]
    @State private var particles: [AmbientParticle] = []
    @State private var animationTimer: Timer?
    
    struct AmbientParticle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var size: CGFloat
        var color: Color
        var opacity: Double
        var pulsePhase: Double = 0
        var velocity: CGSize = .zero
        var driftPhase: Double = 0 // For slow drift animation
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    particle.color.opacity(particle.opacity),
                                    particle.color.opacity(particle.opacity * 0.5),
                                    particle.color.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: particle.size * 0.3,
                                endRadius: particle.size
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        // Phase 10: Optimize blur radius for performance
                        .blur(radius: PerformanceManager.optimalBlurRadius(baseRadius: particle.size * 0.2))
                        .scaleEffect(1.0 + sin(particle.pulsePhase) * 0.1) // Gentle pulsing
                }
            }
        }
        // Phase 10: Use drawingGroup for performance optimization
        .drawingGroup()
        .ignoresSafeArea(.all)
        .onAppear {
            generateParticles()
            startAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
        .onChange(of: tracks.count) { _, _ in
            updateParticlesForTracks()
        }
    }
    
    // Phase 10: Performance optimization - limit particle count
    private func generateParticles() {
        var newParticles: [AmbientParticle] = []
        
        let activeTracks = tracks.filter({ $0.volume > 0 })
        let maxParticles = PerformanceManager.optimalParticleCount(activeTracks: activeTracks.count)
        let particlesPerTrack = min(PerformanceManager.maxParticlesPerTrack, maxParticles / max(activeTracks.count, 1))
        
        // Generate particles per active track (limited for performance)
        for track in activeTracks {
            let count = min(Int.random(in: 3...5), particlesPerTrack)
            let color = SoundColor.colorForTrack(track.name)
            
            for _ in 0..<count {
                newParticles.append(
                    AmbientParticle(
                        position: CGPoint(
                            x: CGFloat.random(in: 100...800),
                            y: CGFloat.random(in: 100...1200)
                        ),
                        size: CGFloat.random(in: 100...300),
                        color: color,
                        opacity: Double.random(in: 0.08...0.15) * track.volume,
                        velocity: CGSize(
                            width: CGFloat.random(in: -0.1...0.1),
                            height: CGFloat.random(in: -0.1...0.1)
                        ),
                        driftPhase: Double.random(in: 0...(2 * .pi))
                    )
                )
            }
        }
        
        // Phase 10: Limit total particle count for performance
        particles = Array(newParticles.prefix(maxParticles))
    }
    
    private func startAnimation() {
        // Phase 10: Performance optimization - adjust update interval based on performance settings
        let updateInterval = PerformanceManager.shouldReduceAnimations ? 1.0 : 0.5
        
        // Slow animation cycle: 2-5 minutes (120-300 seconds)
        // Update every 0.5-1.0 seconds for smooth motion (slower in low power mode)
        animationTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        for index in particles.indices {
            // Slow drift movement (2-5 minute cycles)
            let driftSpeed: CGFloat = 0.05 // Very slow
            particles[index].driftPhase += 0.01
            
            // Circular drift pattern
            particles[index].position.x += cos(particles[index].driftPhase) * driftSpeed
            particles[index].position.y += sin(particles[index].driftPhase) * driftSpeed
            
            // Gentle pulse (3-5 second cycle)
            particles[index].pulsePhase += 0.02
            
            // Very gentle velocity changes
            particles[index].velocity.width += CGFloat.random(in: -0.005...0.005)
            particles[index].velocity.height += CGFloat.random(in: -0.005...0.005)
            
            // Clamp velocity
            particles[index].velocity.width = clamp(particles[index].velocity.width, min: -0.1, max: 0.1)
            particles[index].velocity.height = clamp(particles[index].velocity.height, min: -0.1, max: 0.1)
            
            // Apply velocity
            particles[index].position.x += particles[index].velocity.width
            particles[index].position.y += particles[index].velocity.height
            
            // Wrap around screen edges
            if particles[index].position.x < 0 { particles[index].position.x = 800 }
            if particles[index].position.x > 800 { particles[index].position.x = 0 }
            if particles[index].position.y < 0 { particles[index].position.y = 1200 }
            if particles[index].position.y > 1200 { particles[index].position.y = 0 }
        }
    }
    
    private func updateParticlesForTracks() {
        // Regenerate particles when tracks change
        generateParticles()
    }
    
    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Ambient Wave Layer
/// Subtle wave animations at screen edges (0.1-0.3 Hz frequency)
struct AmbientWaveLayer: View {
    @State private var wavePhase: Double = 0
    @State private var waveTimer: Timer?
    let activeTracks: [AudioTrack]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top edge wave
                WaveShape(
                    phase: wavePhase,
                    amplitude: 30,
                    frequency: 0.2,
                    direction: .horizontal
                )
                .fill(
                    LinearGradient(
                        colors: activeTracks.isEmpty ? [
                            Color.white.opacity(0.03),
                            Color.clear
                        ] : [
                            activeTracks.first.map { SoundColor.colorForTrack($0.name).opacity(0.05) } ?? Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(height: 100)
                .offset(y: -geometry.size.height / 2)
                
                // Bottom edge wave
                WaveShape(
                    phase: wavePhase + .pi,
                    amplitude: 30,
                    frequency: 0.2,
                    direction: .horizontal
                )
                .fill(
                    LinearGradient(
                        colors: activeTracks.isEmpty ? [
                            Color.white.opacity(0.03),
                            Color.clear
                        ] : [
                            activeTracks.last.map { SoundColor.colorForTrack($0.name).opacity(0.05) } ?? Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                )
                .frame(height: 100)
                .offset(y: geometry.size.height / 2)
                
                // Left edge wave
                WaveShape(
                    phase: wavePhase,
                    amplitude: 30,
                    frequency: 0.2,
                    direction: .vertical
                )
                .fill(
                    LinearGradient(
                        colors: activeTracks.isEmpty ? [
                            Color.white.opacity(0.03),
                            Color.clear
                        ] : [
                            activeTracks.first.map { SoundColor.colorForTrack($0.name).opacity(0.05) } ?? Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .center
                    )
                )
                .frame(width: 100)
                .offset(x: -geometry.size.width / 2)
                
                // Right edge wave
                WaveShape(
                    phase: wavePhase + .pi,
                    amplitude: 30,
                    frequency: 0.2,
                    direction: .vertical
                )
                .fill(
                    LinearGradient(
                        colors: activeTracks.isEmpty ? [
                            Color.white.opacity(0.03),
                            Color.clear
                        ] : [
                            activeTracks.last.map { SoundColor.colorForTrack($0.name).opacity(0.05) } ?? Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .trailing,
                        endPoint: .center
                    )
                )
                .frame(width: 100)
                .offset(x: geometry.size.width / 2)
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            startWaveAnimation()
        }
        .onDisappear {
            waveTimer?.invalidate()
        }
    }
    
    private func startWaveAnimation() {
        // 0.1-0.3 Hz frequency (very slow)
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                wavePhase += 0.02 // Slow phase increment
            }
        }
    }
}

// MARK: - Wave Shape
struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var frequency: Double
    var direction: WaveDirection
    
    enum WaveDirection {
        case horizontal
        case vertical
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch direction {
        case .horizontal:
            path.move(to: CGPoint(x: 0, y: rect.midY))
            for x in stride(from: 0, through: rect.width, by: 1) {
                let y = rect.midY + amplitude * CGFloat(sin((Double(x) / rect.width * 2 * .pi * frequency) + phase))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
            
        case .vertical:
            path.move(to: CGPoint(x: rect.midX, y: 0))
            for y in stride(from: 0, through: rect.height, by: 1) {
                let x = rect.midX + amplitude * CGFloat(sin((Double(y) / rect.height * 2 * .pi * frequency) + phase))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Depth Fog Layer
/// Radial gradients from screen edges for atmospheric depth
struct DepthFogLayer: View {
    @State private var fogPhase: Double = 0
    @State private var fogTimer: Timer?
    let activeTracks: [AudioTrack]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top fog
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.03 + sin(fogPhase) * 0.02),
                        Color.clear
                    ],
                    center: .init(x: geometry.size.width / 2, y: 0),
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.5
                )
                
                // Bottom fog
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.03 + sin(fogPhase + .pi) * 0.02),
                        Color.clear
                    ],
                    center: .init(x: geometry.size.width / 2, y: geometry.size.height),
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.5
                )
                
                // Left fog
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.03 + sin(fogPhase + .pi / 2) * 0.02),
                        Color.clear
                    ],
                    center: .init(x: 0, y: geometry.size.height / 2),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.5
                )
                
                // Right fog
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.03 + sin(fogPhase + 3 * .pi / 2) * 0.02),
                        Color.clear
                    ],
                    center: .init(x: geometry.size.width, y: geometry.size.height / 2),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.5
                )
            }
        }
        .ignoresSafeArea(.all)
        .blendMode(.multiply)
        .onAppear {
            startFogAnimation()
        }
        .onDisappear {
            fogTimer?.invalidate()
        }
    }
    
    private func startFogAnimation() {
        // 30-60 second cycle for slow pulsing
        fogTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                fogPhase += 0.01 // Very slow phase increment
            }
        }
    }
}

// MARK: - Color Wash Layer (Enhanced)
/// Dynamic color wash from active tracks
struct ColorWashLayer: View {
    let track: AudioTrack
    
    var body: some View {
        let color = SoundColor.colorForTrack(track.name)
        let opacity = 0.12 * track.volume
        
        color
            .opacity(opacity)
            .blendMode(.plusLighter)
            .animation(AppTheme.Animation.fluid, value: track.volume)
            .ignoresSafeArea(.all)
    }
}

// MARK: - Complete Ambient Background System
/// Phase 2: Complete ambient background with all layers
struct AmbientBackgroundSystem: View {
    let activeTracks: [AudioTrack]
    let videoURL: URL?
    
    var body: some View {
        ZStack {
            if let videoURL {
                VideoBackgroundView(url: videoURL)
                    .blur(radius: 24)
                    .opacity(0.28)
                    .allowsHitTesting(false)
            }

            // Layer 1: Base gradient
            AppTheme.background
                .opacity(videoURL == nil ? 1.0 : 0.75)
                .ignoresSafeArea(.all)
            
            // Layer 2: Noise texture overlay
            NoiseTextureView(opacity: 0.008)
            
            // Layer 3: Content-driven color gradient
            if !activeTracks.isEmpty {
                let trackNames = activeTracks.map { $0.name }
                AppTheme.contentGradient(for: trackNames)
                    .opacity(0.3)
                    .blendMode(.plusLighter)
                    .ignoresSafeArea(.all)
            }
            
            // Layer 4: Color wash from active tracks
            ForEach(activeTracks.filter { $0.volume > 0 }, id: \.id) { track in
                ColorWashLayer(track: track)
            }
            
            // Layer 5: Particle system (3-5 orbs per active track)
            AmbientParticleSystem(tracks: activeTracks.filter { $0.volume > 0 })
            
            // Layer 6: Ambient waves at edges
            AmbientWaveLayer(activeTracks: activeTracks.filter { $0.volume > 0 })
            
            // Layer 7: Depth fog
            DepthFogLayer(activeTracks: activeTracks.filter { $0.volume > 0 })
        }
        .ignoresSafeArea(.all)
    }
}

