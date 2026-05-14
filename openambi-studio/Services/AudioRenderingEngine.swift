import AVFoundation
import Accelerate

// MARK: - Audio Rendering Engine
// Best-in-class audio pipeline using AVAudioEngine for per-track
// spatial positioning, parametric EQ, reverb, and crossfade looping.

// MARK: - Per-Track Effect Configuration

struct AudioEffectConfig: Equatable {
    /// 3D position in unit sphere coordinates (-1...1 for x/y/z)
    var spatialPosition: SIMD3<Float> = .zero
    
    /// Reverb wet/dry mix (0 = dry, 1 = full wet)
    var reverbMix: Float = 0.0
    
    /// Reverb preset
    var reverbPreset: AVAudioUnitReverbPreset = .cathedral
    
    /// Parametric EQ bands
    var eqBands: EQBands = EQBands()
    
    /// Crossfade overlap duration in seconds for gapless looping
    var crossfadeDuration: TimeInterval = 0.15
    
    static func == (lhs: AudioEffectConfig, rhs: AudioEffectConfig) -> Bool {
        lhs.spatialPosition == rhs.spatialPosition &&
        lhs.reverbMix == rhs.reverbMix &&
        lhs.eqBands == rhs.eqBands &&
        lhs.crossfadeDuration == rhs.crossfadeDuration
    }
}

struct EQBands: Equatable {
    /// Low shelf gain in dB (-24...+24)
    var lowGain: Float = 0
    /// Low shelf frequency (20-500 Hz)
    var lowFreq: Float = 80
    
    /// Mid peak gain in dB
    var midGain: Float = 0
    /// Mid center frequency (200-5000 Hz)
    var midFreq: Float = 1000
    /// Mid bandwidth (octaves)
    var midBandwidth: Float = 1.0
    
    /// High shelf gain in dB
    var highGain: Float = 0
    /// High shelf frequency (2000-20000 Hz)
    var highFreq: Float = 8000
}

// MARK: - Rendered Track Handle

/// Represents a single track loaded into the rendering engine.
final class RenderedTrack {
    let id: UUID
    let playerA: AVAudioPlayerNode
    let playerB: AVAudioPlayerNode   // Second player for crossfade looping
    let eq: AVAudioUnitEQ
    let reverb: AVAudioUnitReverb
    let mixer: AVAudioMixerNode      // Per-track volume / pan
    
    var file: AVAudioFile?
    var activePlayer: AVAudioPlayerNode  // Currently audible player
    var config: AudioEffectConfig = AudioEffectConfig()
    var isPlaying = false
    
    init(id: UUID) {
        self.id = id
        self.playerA = AVAudioPlayerNode()
        self.playerB = AVAudioPlayerNode()
        self.eq = AVAudioUnitEQ(numberOfBands: 3)
        self.reverb = AVAudioUnitReverb()
        self.mixer = AVAudioMixerNode()
        self.activePlayer = playerA
    }
}

// MARK: - Audio Rendering Engine

final class AudioRenderingEngine {
    static let shared = AudioRenderingEngine()
    
    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    
    // Limiter on the master bus to prevent clipping
    private let limiter = AVAudioUnitEffect(
        audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    )
    
    private var tracks: [UUID: RenderedTrack] = [:]
    private let processingQueue = DispatchQueue(label: "com.openambi.audioengine", qos: .userInteractive)
    private(set) var isRunning = false
    
    // Loudness normalization target in LUFS
    private let targetLoudness: Float = -14.0
    
    private init() {
        configureGraph()
    }
    
    // MARK: - Graph Setup
    
    private func configureGraph() {
        engine.attach(masterMixer)
        engine.attach(limiter)
        
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        
        // Master mixer -> Limiter -> Output
        engine.connect(masterMixer, to: limiter, format: outputFormat)
        engine.connect(limiter, to: engine.mainMixerNode, format: outputFormat)
        
        engine.prepare()
    }
    
    func start() throws {
        guard !isRunning else { return }
        try engine.start()
        isRunning = true
        print("AudioRenderingEngine started")
    }
    
    func stop() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        print("AudioRenderingEngine stopped")
    }
    
    // MARK: - Track Lifecycle
    
    /// Load a track from a local or remote URL.
    /// Returns immediately; audio is ready to play once the file is buffered.
    func loadTrack(id: UUID, url: URL) throws -> RenderedTrack {
        let track = RenderedTrack(id: id)
        
        // Load audio file
        let file = try AVAudioFile(forReading: url)
        track.file = file
        
        let processingFormat = file.processingFormat
        
        // Attach all nodes
        engine.attach(track.playerA)
        engine.attach(track.playerB)
        engine.attach(track.eq)
        engine.attach(track.reverb)
        engine.attach(track.mixer)
        
        // Configure EQ (3-band parametric: low shelf, mid peak, high shelf)
        configurEQ(track.eq)
        
        // Configure reverb defaults
        track.reverb.loadFactoryPreset(.cathedral)
        track.reverb.wetDryMix = 0 // Start dry
        
        // Wire: PlayerA -> EQ -> Reverb -> Track Mixer -> Master
        // Wire: PlayerB -> EQ (shared) -> ... same chain
        // Both players feed into the same EQ
        engine.connect(track.playerA, to: track.eq, format: processingFormat)
        engine.connect(track.playerB, to: track.eq, format: processingFormat)
        engine.connect(track.eq, to: track.reverb, format: processingFormat)
        engine.connect(track.reverb, to: track.mixer, format: processingFormat)
        
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(track.mixer, to: masterMixer, format: outputFormat)
        
        tracks[id] = track
        
        // Start engine if not running
        if !isRunning {
            try start()
        }
        
        return track
    }
    
    func unloadTrack(id: UUID) {
        guard let track = tracks.removeValue(forKey: id) else { return }
        
        track.playerA.stop()
        track.playerB.stop()
        
        engine.detach(track.playerA)
        engine.detach(track.playerB)
        engine.detach(track.eq)
        engine.detach(track.reverb)
        engine.detach(track.mixer)
        
        print("Unloaded track from rendering engine: \(id)")
        
        if tracks.isEmpty {
            stop()
        }
    }
    
    // MARK: - Playback
    
    /// Play a track with crossfade looping.
    func play(trackId: UUID, volume: Float = 1.0) {
        guard let track = tracks[trackId], let file = track.file else { return }
        
        track.mixer.outputVolume = volume
        track.isPlaying = true
        
        scheduleLoop(track: track, player: track.playerA, file: file)
        track.playerA.play()
        track.activePlayer = track.playerA
    }
    
    func pause(trackId: UUID) {
        guard let track = tracks[trackId] else { return }
        track.playerA.pause()
        track.playerB.pause()
        track.isPlaying = false
    }
    
    func resume(trackId: UUID) {
        guard let track = tracks[trackId] else { return }
        track.activePlayer.play()
        track.isPlaying = true
    }
    
    func setVolume(trackId: UUID, volume: Float) {
        guard let track = tracks[trackId] else { return }
        track.mixer.outputVolume = volume
    }
    
    /// Smoothly ramp volume using AVAudioMixerNode scheduling
    func rampVolume(trackId: UUID, to target: Float, duration: TimeInterval) {
        guard let track = tracks[trackId] else { return }
        
        let startVolume = track.mixer.outputVolume
        let steps = max(Int(duration * 120), 1)
        let stepDuration = duration / Double(steps)
        let delta = target - startVolume
        
        processingQueue.async {
            for step in 0...steps {
                let progress = Float(step) / Float(steps)
                // Use ease-in-out curve for natural feel
                let curved = 0.5 * (1.0 - cos(Float.pi * progress))
                let vol = startVolume + delta * curved
                
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                    track.mixer.outputVolume = vol
                }
            }
        }
    }
    
    // MARK: - Effects Control
    
    func updateEffects(trackId: UUID, config: AudioEffectConfig) {
        guard let track = tracks[trackId] else { return }
        track.config = config
        
        // Spatial position -> pan (simplified stereo panning from x coordinate)
        track.mixer.pan = config.spatialPosition.x
        
        // Reverb
        track.reverb.wetDryMix = config.reverbMix * 100.0 // AVAudioUnitReverb uses 0-100
        if track.reverb.wetDryMix > 0 {
            track.reverb.loadFactoryPreset(config.reverbPreset)
        }
        
        // EQ
        applyEQ(track.eq, bands: config.eqBands)
    }
    
    /// Update only the spatial position for a track (lightweight).
    func setSpatialPosition(trackId: UUID, position: SIMD3<Float>) {
        guard let track = tracks[trackId] else { return }
        track.config.spatialPosition = position
        track.mixer.pan = position.x
    }
    
    /// Update only the reverb for a track.
    func setReverb(trackId: UUID, mix: Float, preset: AVAudioUnitReverbPreset = .cathedral) {
        guard let track = tracks[trackId] else { return }
        track.config.reverbMix = mix
        track.config.reverbPreset = preset
        track.reverb.wetDryMix = mix * 100.0
        if mix > 0 {
            track.reverb.loadFactoryPreset(preset)
        }
    }
    
    /// Update only the EQ for a track.
    func setEQ(trackId: UUID, bands: EQBands) {
        guard let track = tracks[trackId] else { return }
        track.config.eqBands = bands
        applyEQ(track.eq, bands: bands)
    }
    
    // MARK: - Master Bus
    
    var masterVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }
    
    // MARK: - Crossfade Looping
    
    private func scheduleLoop(track: RenderedTrack, player: AVAudioPlayerNode, file: AVAudioFile) {
        let crossfadeDuration = track.config.crossfadeDuration
        let sampleRate = file.processingFormat.sampleRate
        let totalFrames = AVAudioFrameCount(file.length)
        let crossfadeFrames = AVAudioFrameCount(crossfadeDuration * sampleRate)
        
        // If file is very short, use simple looping
        guard totalFrames > crossfadeFrames * 3 else {
            player.scheduleFile(file, at: nil) { [weak self] in
                self?.processingQueue.async {
                    guard track.isPlaying else { return }
                    file.framePosition = 0
                    self?.scheduleLoop(track: track, player: player, file: file)
                    if player.isPlaying == false {
                        player.play()
                    }
                }
            }
            return
        }
        
        // Schedule the main body of the audio
        file.framePosition = 0
        player.scheduleFile(file, at: nil) { [weak self] in
            self?.processingQueue.async {
                guard track.isPlaying else { return }
                // Crossfade: start the other player slightly before this one ends
                self?.performCrossfade(track: track, file: file)
            }
        }
    }
    
    private func performCrossfade(track: RenderedTrack, file: AVAudioFile) {
        let incoming: AVAudioPlayerNode
        let outgoing: AVAudioPlayerNode
        
        if track.activePlayer === track.playerA {
            incoming = track.playerB
            outgoing = track.playerA
        } else {
            incoming = track.playerA
            outgoing = track.playerB
        }
        
        // Schedule the incoming player from the start
        file.framePosition = 0
        incoming.volume = 0
        
        scheduleLoop(track: track, player: incoming, file: file)
        incoming.play()
        
        // Crossfade volumes
        let crossfadeDuration = track.config.crossfadeDuration
        let steps = max(Int(crossfadeDuration * 120), 1)
        let stepDuration = crossfadeDuration / Double(steps)
        let trackVolume = track.mixer.outputVolume
        
        for step in 0...steps {
            let progress = Float(step) / Float(steps)
            let curved = 0.5 * (1.0 - cos(Float.pi * progress))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                incoming.volume = curved
                outgoing.volume = 1.0 - curved
            }
        }
        
        // After crossfade completes, stop the outgoing player
        DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeDuration + 0.05) {
            outgoing.stop()
            outgoing.volume = 1.0
        }
        
        track.activePlayer = incoming
    }
    
    // MARK: - EQ Configuration
    
    private func configurEQ(_ eq: AVAudioUnitEQ) {
        guard eq.bands.count >= 3 else { return }
        
        // Band 0: Low shelf
        let low = eq.bands[0]
        low.filterType = .lowShelf
        low.frequency = 80
        low.gain = 0
        low.bypass = false
        
        // Band 1: Parametric mid
        let mid = eq.bands[1]
        mid.filterType = .parametric
        mid.frequency = 1000
        mid.bandwidth = 1.0
        mid.gain = 0
        mid.bypass = false
        
        // Band 2: High shelf
        let high = eq.bands[2]
        high.filterType = .highShelf
        high.frequency = 8000
        high.gain = 0
        high.bypass = false
    }
    
    private func applyEQ(_ eq: AVAudioUnitEQ, bands: EQBands) {
        guard eq.bands.count >= 3 else { return }
        
        let low = eq.bands[0]
        low.frequency = bands.lowFreq
        low.gain = bands.lowGain
        
        let mid = eq.bands[1]
        mid.frequency = bands.midFreq
        mid.bandwidth = bands.midBandwidth
        mid.gain = bands.midGain
        
        let high = eq.bands[2]
        high.frequency = bands.highFreq
        high.gain = bands.highGain
    }
    
    // MARK: - Loudness Analysis (LUFS approximation)
    
    /// Analyze loudness of an audio file and return a gain adjustment to hit targetLoudness.
    func analyzeLoudness(file: AVAudioFile) -> Float {
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(min(file.length, AVAudioFramePosition(format.sampleRate * 10))) // Analyze first 10s
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return 0
        }
        
        file.framePosition = 0
        do {
            try file.read(into: buffer)
        } catch {
            return 0
        }
        
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelCount = Int(format.channelCount)
        let sampleCount = Int(buffer.frameLength)
        
        guard sampleCount > 0 else { return 0 }
        
        // Calculate RMS across all channels
        var totalRMS: Float = 0
        for ch in 0..<channelCount {
            var sumSquared: Float = 0
            vDSP_svesq(channelData[ch], 1, &sumSquared, vDSP_Length(sampleCount))
            totalRMS += sumSquared / Float(sampleCount)
        }
        totalRMS /= Float(channelCount)
        
        guard totalRMS > 0 else { return 0 }
        
        // Convert to approximate LUFS (simplified: 20*log10(rms))
        let measuredLoudness = 20.0 * log10(sqrt(totalRMS))
        let gainAdjustment = targetLoudness - measuredLoudness
        
        // Clamp to prevent extreme adjustments
        return max(-12, min(12, gainAdjustment))
    }
    
    /// Apply loudness normalization to a track
    func normalizeLoudness(trackId: UUID) {
        guard let track = tracks[trackId], let file = track.file else { return }
        
        let gainDB = analyzeLoudness(file: file)
        let gainLinear = pow(10.0, gainDB / 20.0)
        
        // Apply gain via the EQ global gain
        track.eq.globalGain = gainDB
        
        print("Loudness normalization for \(trackId): \(String(format: "%.1f", gainDB)) dB (linear: \(String(format: "%.3f", gainLinear)))")
    }
    
    // MARK: - Diagnostic
    
    var trackCount: Int { tracks.count }
    
    func trackIds() -> [UUID] {
        Array(tracks.keys)
    }
}
