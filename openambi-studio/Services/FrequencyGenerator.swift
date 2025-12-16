import AVFoundation
import Combine
import Foundation
import Accelerate

class FrequencyGenerator: ObservableObject {
    private let engine = AVAudioEngine()
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var frequencyTracks: [UUID: FrequencyTrack] = [:]
    private var phaseStates: [UUID: PhaseState] = [:] // Track phase for seamless looping
    private var volumeRampTasks: [UUID: DispatchWorkItem] = [:] // Track active volume ramps
    private var isEngineRunning = false
    private let audioSessionQueue = DispatchQueue(label: "com.openambi.frequencygenerator", qos: .userInitiated)
    
    // Fixed sample rate to prevent drift (match common audio file rate)
    private let fixedSampleRate: Double = 44100.0
    
    // Get sample rate - use fixed rate to prevent drift
    private var sampleRate: Double {
        return fixedSampleRate
    }
    
    // Buffer duration - longer for smoother playback (4 seconds)
    private let bufferDuration: Double = 4.0
    
    // Volume ramp duration (50ms for smooth transitions)
    private let volumeRampDuration: TimeInterval = 0.05
    
    // Fade in/out samples at buffer edges to prevent clicks (64 samples = ~1.45ms at 44.1kHz)
    private let fadeSamples: Int = 64
    
    // Default isochronic AM depth (0.0 to 1.0)
    private var isochronicDepth: [UUID: Float] = [:]
    
    // Spectrum analyzer (optional, for debugging)
    private var isSpectrumEnabled = false
    
    struct FrequencyTrack {
        let id: UUID
        let type: FrequencyType
        var volume: Float
        var isActive: Bool
    }
    
    // Track phase state for seamless looping
    private struct PhaseState {
        var leftPhase: Double = 0.0 // Left channel phase in radians
        var rightPhase: Double = 0.0 // Right channel phase in radians
        var pulsePhase: Double = 0.0 // For isochronic tones
    }
    
    init() {
        // Configure audio engine for high-quality playback
        // Set output volume to 0.7 to prevent headroom issues
        engine.mainMixerNode.outputVolume = 0.7
        
        // Prepare the engine (but don't start until needed)
        engine.prepare()
    }
    
    // MARK: - Configuration
    
    /// Set isochronic tone AM depth (0.0 = no modulation, 1.0 = full modulation)
    func setIsochronicDepth(trackId: UUID, depth: Float) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isochronicDepth[trackId] = max(0.0, min(1.0, depth))
            print("🎛️ Set isochronic depth for \(trackId): \(depth)")
        }
    }
    
    /// Enable/disable spectrum analyzer for debugging
    func setSpectrumEnabled(_ enabled: Bool) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            if enabled && !self.isSpectrumEnabled {
                self.installSpectrumTap()
            } else if !enabled && self.isSpectrumEnabled {
                self.removeSpectrumTap()
            }
            self.isSpectrumEnabled = enabled
        }
    }
    
    func startFrequency(trackId: UUID, type: FrequencyType, volume: Float) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If track already exists, just update volume and resume
            if let existingNode = self.playerNodes[trackId] {
                existingNode.volume = volume
                existingNode.play()
                if var track = self.frequencyTracks[trackId] {
                    track.volume = volume
                    track.isActive = true
                    self.frequencyTracks[trackId] = track
                }
                print("🎵 Resumed existing frequency track: \(trackId), volume: \(volume)")
                return
            }
            
            // Initialize phase state for seamless looping
            self.phaseStates[trackId] = PhaseState()
            
            // Create new player node
            let playerNode = AVAudioPlayerNode()
            self.engine.attach(playerNode)
            
            // Connect to main mixer with proper format
            let format = AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 2)!
            self.engine.connect(playerNode, to: self.engine.mainMixerNode, format: format)
            
            // Ensure audio session is active before starting engine
            do {
                let audioSession = AVAudioSession.sharedInstance()
                if !audioSession.isOtherAudioPlaying {
                    try audioSession.setActive(true, options: [])
                }
            } catch {
                print("⚠️ Could not activate audio session: \(error)")
            }
            
            // Start engine if not running (must be before scheduling)
            if !self.isEngineRunning {
                do {
                    try self.engine.start()
                    self.isEngineRunning = true
                    print("✅ Frequency generator engine started at \(self.sampleRate) Hz")
                } catch {
                    print("❌ Failed to start frequency generator engine: \(error)")
                    self.engine.detach(playerNode)
                    return
                }
            }
            
            // Schedule multiple buffers ahead for seamless playback
            // Schedule 3 buffers initially to prevent gaps
            self.scheduleBufferChain(playerNode: playerNode, trackId: trackId, type: type, count: 3)
            
            self.playerNodes[trackId] = playerNode
            self.frequencyTracks[trackId] = FrequencyTrack(id: trackId, type: type, volume: volume, isActive: true)
            
            // Ramp volume in smoothly to prevent clicks
            playerNode.volume = 0.0 as Float
            self.rampVolume(trackId: trackId, to: volume, duration: self.volumeRampDuration)
            
            // Start playback
            playerNode.play()
            
            print("🎵 Started frequency track: \(trackId), type: \(type), volume: \(volume), sampleRate: \(self.sampleRate)")
        }
    }
    
    // Schedule a chain of buffers for seamless looping
    private func scheduleBufferChain(playerNode: AVAudioPlayerNode, trackId: UUID, type: FrequencyType, count: Int) {
        for i in 0..<count {
            let buffer = generateBuffer(for: type, trackId: trackId)
            let isLast = (i == count - 1)
            
            if isLast {
                // Last buffer schedules the next one for continuous looping
                playerNode.scheduleBuffer(buffer) { [weak self] in
                    // When buffer finishes, schedule another one for seamless looping
                    guard let self = self, self.playerNodes[trackId] != nil else { return }
                    
                    // Schedule next buffer - use audio session queue for thread safety
                    self.audioSessionQueue.async {
                        guard self.playerNodes[trackId] != nil else { return }
                        let nextBuffer = self.generateBuffer(for: type, trackId: trackId)
                        self.playerNodes[trackId]?.scheduleBuffer(nextBuffer) { [weak self] in
                            // Continue the chain recursively
                            self?.scheduleNextBuffer(trackId: trackId, type: type)
                        }
                    }
                }
            } else {
                // Intermediate buffers just schedule normally
                playerNode.scheduleBuffer(buffer, completionHandler: nil)
            }
        }
    }
    
    // Helper to schedule next buffer in the chain
    private func scheduleNextBuffer(trackId: UUID, type: FrequencyType) {
        guard playerNodes[trackId] != nil else { return }
        audioSessionQueue.async { [weak self] in
            guard let self = self, let playerNode = self.playerNodes[trackId] else { return }
            let buffer = self.generateBuffer(for: type, trackId: trackId)
            playerNode.scheduleBuffer(buffer) { [weak self] in
                // Continue scheduling
                self?.scheduleNextBuffer(trackId: trackId, type: type)
            }
        }
    }
    
    func stopFrequency(trackId: UUID) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let playerNode = self.playerNodes[trackId] else {
                print("⚠️ No player node found for track: \(trackId)")
                return
            }
            
            // Cancel any active volume ramp
            self.volumeRampTasks[trackId]?.cancel()
            self.volumeRampTasks.removeValue(forKey: trackId)
            
            // Ramp volume down smoothly before stopping
            self.rampVolume(trackId: trackId, to: 0.0 as Float, duration: self.volumeRampDuration) { [weak self] in
                guard let self = self else { return }
                self.audioSessionQueue.async {
                    guard let playerNode = self.playerNodes[trackId] else { return }
                    
                    playerNode.stop()
                    playerNode.reset()
                    self.engine.detach(playerNode)
                    self.playerNodes.removeValue(forKey: trackId)
                    self.frequencyTracks.removeValue(forKey: trackId)
                    self.phaseStates.removeValue(forKey: trackId)
                    self.isochronicDepth.removeValue(forKey: trackId)
                    
                    print("⏸️ Stopped frequency track: \(trackId)")
                    
                    // Stop engine if no active tracks
                    if self.playerNodes.isEmpty && self.isEngineRunning {
                        self.engine.stop()
                        self.isEngineRunning = false
                        print("🛑 Frequency generator engine stopped (no active tracks)")
                    }
                }
            }
        }
    }
    
    // Overloaded rampVolume with completion handler
    private func rampVolume(trackId: UUID, to targetVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let playerNode = playerNodes[trackId] else {
            completion?()
            return
        }
        
        let startVolume = playerNode.volume
        let steps = Int(duration * 1000) // Update every 1ms
        let stepDuration = duration / Double(steps)
        let volumeDelta = targetVolume - startVolume
        
        var currentStep = 0
        
        // Create a recursive function that doesn't capture workItem before declaration
        func performStep() {
            guard let node = playerNodes[trackId] else {
                completion?()
                return
            }
            
            if currentStep < steps {
                let progress = Float(currentStep) / Float(steps)
                let currentVolume = startVolume + (volumeDelta * progress)
                node.volume = currentVolume
                currentStep += 1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                    performStep()
                }
            } else {
                // Ensure final volume is exact
                node.volume = targetVolume
                volumeRampTasks.removeValue(forKey: trackId)
                completion?()
            }
        }
        
        // Store a work item that can be cancelled
        let workItem = DispatchWorkItem {
            performStep()
        }
        
        volumeRampTasks[trackId] = workItem
        workItem.perform()
    }
    
    func updateVolume(trackId: UUID, volume: Float) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.playerNodes[trackId] != nil else {
                return
            }
            
            // Cancel any existing ramp for this track
            self.volumeRampTasks[trackId]?.cancel()
            
            // Ramp volume smoothly
            self.rampVolume(trackId: trackId, to: volume, duration: self.volumeRampDuration)
            
            if var track = self.frequencyTracks[trackId] {
                track.volume = volume
                self.frequencyTracks[trackId] = track
            }
            
            print("🔊 Updated frequency track volume: \(trackId), volume: \(volume)")
        }
    }
    
    // MARK: - Volume Ramping
    
    /// Smoothly ramp volume over specified duration
    private func rampVolume(trackId: UUID, to targetVolume: Float, duration: TimeInterval) {
        guard let playerNode = playerNodes[trackId] else { return }
        
        let startVolume = playerNode.volume
        let steps = Int(duration * 1000) // Update every 1ms
        let stepDuration = duration / Double(steps)
        let volumeDelta = targetVolume - startVolume
        
        var currentStep = 0
        
        // Create a recursive function that doesn't capture workItem before declaration
        func performStep() {
            guard let node = playerNodes[trackId] else { return }
            
            if currentStep < steps {
                let progress = Float(currentStep) / Float(steps)
                let currentVolume = startVolume + (volumeDelta * progress)
                node.volume = currentVolume
                currentStep += 1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                    performStep()
                }
            } else {
                // Ensure final volume is exact
                node.volume = targetVolume
                volumeRampTasks.removeValue(forKey: trackId)
            }
        }
        
        // Store a work item that can be cancelled
        let workItem = DispatchWorkItem {
            performStep()
        }
        
        volumeRampTasks[trackId] = workItem
        workItem.perform()
    }
    
    func pauseFrequency(trackId: UUID) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.playerNodes[trackId]?.pause()
        }
    }
    
    func resumeFrequency(trackId: UUID) {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.playerNodes[trackId]?.play()
        }
    }
    
    private func generateBuffer(for type: FrequencyType, trackId: UUID) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * bufferDuration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create buffer")
            return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        }
        buffer.frameLength = frameCount
        
        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            print("❌ Failed to get channel data for buffer")
            return buffer
        }
        
        // Get or initialize phase state
        var phaseState = phaseStates[trackId] ?? PhaseState()
        
        // Track if this is the first buffer (for fade-in only)
        let isFirstBuffer = phaseState.leftPhase == 0.0 && phaseState.rightPhase == 0.0 && phaseState.pulsePhase == 0.0
        
        switch type {
        case .pureTone(let frequency):
            // Same frequency to both channels with phase continuity
            phaseState.leftPhase = generateSineWave(
                channel: leftChannel,
                frequency: frequency,
                frameCount: frameCount,
                startPhase: phaseState.leftPhase
            )
            phaseState.rightPhase = generateSineWave(
                channel: rightChannel,
                frequency: frequency,
                frameCount: frameCount,
                startPhase: phaseState.rightPhase
            )
            
        case .binauralBeat(let baseFreq, let beatFreq):
            // Different frequencies to each ear with independent phase continuity
            let leftFreq = baseFreq
            let rightFreq = baseFreq + beatFreq
            phaseState.leftPhase = generateSineWave(
                channel: leftChannel,
                frequency: leftFreq,
                frameCount: frameCount,
                startPhase: phaseState.leftPhase
            )
            phaseState.rightPhase = generateSineWave(
                channel: rightChannel,
                frequency: rightFreq,
                frameCount: frameCount,
                startPhase: phaseState.rightPhase
            )
            
        case .isochronicTone(let frequency, let pulseRate):
            // Pulsed tone to both channels with phase continuity
            let result = generateIsochronicTone(
                leftChannel: leftChannel,
                rightChannel: rightChannel,
                frequency: frequency,
                pulseRate: pulseRate,
                frameCount: frameCount,
                startPhase: phaseState.leftPhase,
                startPulsePhase: phaseState.pulsePhase,
                trackId: trackId
            )
            phaseState.leftPhase = result.phase
            phaseState.rightPhase = result.phase // Same phase for both channels in isochronic
            phaseState.pulsePhase = result.pulsePhase
        }
        
        // Save updated phase state
        phaseStates[trackId] = phaseState
        
        // Apply minimal fade-in only on first buffer to prevent startup clicks
        // Phase continuity handles seamless looping, so no fade-out needed
        if isFirstBuffer && fadeSamples > 0 {
            let fadeInEnd = min(fadeSamples, Int(frameCount))
            for i in 0..<fadeInEnd {
                let fadeFactor = Float(i) / Float(fadeInEnd)
                leftChannel[i] *= fadeFactor
                rightChannel[i] *= fadeFactor
            }
        }
        
        return buffer
    }
    
    // Generate sine wave with phase continuity for seamless looping
    // Returns the final phase for next buffer
    @discardableResult
    private func generateSineWave(
        channel: UnsafeMutablePointer<Float>,
        frequency: Double,
        frameCount: AVAudioFrameCount,
        startPhase: Double
    ) -> Double {
        let phaseIncrement = 2.0 * .pi * frequency / sampleRate
        var currentPhase = startPhase
        let amplitude: Float = 0.3 // 30% amplitude to prevent clipping
        
        for i in 0..<Int(frameCount) {
            channel[i] = Float(sin(currentPhase)) * amplitude
            currentPhase += phaseIncrement
            
            // Normalize phase to prevent overflow (keep in 0..2π range)
            if currentPhase > 2.0 * .pi {
                currentPhase -= 2.0 * .pi
            }
        }
        
        return currentPhase
    }
    
    // Generate isochronic tone with phase continuity for seamless looping
    private func generateIsochronicTone(
        leftChannel: UnsafeMutablePointer<Float>,
        rightChannel: UnsafeMutablePointer<Float>,
        frequency: Double,
        pulseRate: Double,
        frameCount: AVAudioFrameCount,
        startPhase: Double,
        startPulsePhase: Double,
        trackId: UUID
    ) -> (phase: Double, pulsePhase: Double) {
        let phaseIncrement = 2.0 * .pi * frequency / sampleRate
        let pulsePeriod = sampleRate / pulseRate // Frames per pulse cycle
        let pulsePhaseIncrement = 2.0 * .pi / pulsePeriod // Phase increment per frame for pulse
        
        var currentPhase = startPhase
        var currentPulsePhase = startPulsePhase
        let baseAmplitude: Float = 0.3
        
        // Get AM depth for this track (default 0.7 if not set)
        let depth = isochronicDepth[trackId] ?? 0.7
        
        for i in 0..<Int(frameCount) {
            // Calculate pulse amplitude using smooth envelope (sine wave for smooth transitions)
            // Apply depth parameter to control modulation strength
            let rawPulseAmplitude = (sin(currentPulsePhase) + 1.0) / 2.0 // 0.0 to 1.0
            // Apply depth: 0.0 = no modulation (constant), 1.0 = full modulation
            let pulseAmplitude = 1.0 - (Double(depth) * (1.0 - rawPulseAmplitude))
            let amplitude = Float(pulseAmplitude) * baseAmplitude
            
            // Generate sine wave sample
            let sample = Float(sin(currentPhase)) * amplitude
            
            leftChannel[i] = sample
            rightChannel[i] = sample
            
            // Advance phases
            currentPhase += phaseIncrement
            currentPulsePhase += pulsePhaseIncrement
            
            // Normalize phases to prevent overflow
            if currentPhase > 2.0 * .pi {
                currentPhase -= 2.0 * .pi
            }
            if currentPulsePhase > 2.0 * .pi {
                currentPulsePhase -= 2.0 * .pi
            }
        }
        
        return (currentPhase, currentPulsePhase)
    }
    
    // MARK: - Spectrum Analyzer
    
    private func installSpectrumTap() {
        let bufferSize: AVAudioFrameCount = 4096
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.analyzeSpectrum(buffer: buffer)
        }
        
        print("📊 Spectrum analyzer enabled")
    }
    
    private func removeSpectrumTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
        print("📊 Spectrum analyzer disabled")
    }
    
    private var lastSpectrumLog: Date = Date()
    
    private func analyzeSpectrum(buffer: AVAudioPCMBuffer) {
        // Only log every 0.5 seconds to avoid spam
        let now = Date()
        guard now.timeIntervalSince(lastSpectrumLog) >= 0.5 else { return }
        lastSpectrumLog = now
        
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else { return }
        
        let frameCount = Int(buffer.frameLength)
        let log2n = UInt(round(log2(Double(frameCount))))
        let fftSize = 1 << log2n
        
        // Allocate FFT buffers
        var realp = [Float](repeating: 0, count: Int(fftSize / 2))
        var imagp = [Float](repeating: 0, count: Int(fftSize / 2))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
            print("❌ Failed to create FFT setup")
            return
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Create split complex buffer
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Copy input data
        channelData.withMemoryRebound(to: Float.self, capacity: frameCount) { inputPtr in
            vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(inputPtr)), 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude
        var magnitudes = [Float](repeating: 0, count: Int(fftSize / 2))
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // Find dominant frequencies
        let sampleRate = self.sampleRate
        var peakFrequencies: [(frequency: Double, magnitude: Float)] = []
        
        for i in 1..<Int(fftSize / 2) {
            let frequency = Double(i) * sampleRate / Double(fftSize)
            let magnitude = magnitudes[i]
            
            // Only consider frequencies in audible range (20 Hz to 20 kHz)
            if frequency >= 20 && frequency <= 20000 && magnitude > 0.01 as Float {
                peakFrequencies.append((frequency: frequency, magnitude: magnitude))
            }
        }
        
        // Sort by magnitude and get top 3
        peakFrequencies.sort { $0.magnitude > $1.magnitude }
        let topFrequencies = Array(peakFrequencies.prefix(3))
        
        if !topFrequencies.isEmpty {
            let freqStrings = topFrequencies.map { String(format: "%.1f Hz (%.2f)", $0.frequency, $0.magnitude) }
            print("📊 Spectrum: \(freqStrings.joined(separator: ", "))")
        }
    }
}
