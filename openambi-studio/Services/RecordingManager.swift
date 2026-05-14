import Foundation
import AVFoundation
import Combine
import SwiftUI
import CoreLocation

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
    case countdown(Int) // Countdown from 3 to 1
    case recording
    case paused
    case processing
    case completed
    case error(String)
}

// MARK: - Recording Result
struct RecordingResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let videoURL: URL?
    let duration: TimeInterval
    let fileSize: Int64
    let averageLevel: Double
    let peakLevel: Double
}

// MARK: - Recording Manager
class RecordingManager: NSObject, ObservableObject {
    static let shared = RecordingManager()
    
    // Published properties
    @Published var recordingState: RecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Double = 0.0 // 0.0 to 1.0
    
    // Recording components
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    
    // Audio session
    private let audioSession = AVAudioSession.sharedInstance()
    
    // File management
    private let fileManager = FileManager.default
    
    override init() {
        super.init()
        // Don't configure audio session in init - wait until recording starts
        // This prevents conflicts with AudioManager's audio session configuration
    }
    
    // MARK: - Permission Check
    func checkMicrophonePermission() async -> Bool {
        let permissionsManager = PermissionsManager.shared
        return await permissionsManager.requestMicrophonePermission()
    }
    
    /// Checks if microphone permission is currently granted (without requesting)
    func hasMicrophonePermission() -> Bool {
        return PermissionsManager.shared.hasMicrophonePermission
    }
    
    // MARK: - Start Recording with Countdown
    func startRecording() async throws {
        // Check permission with proper handling
        let hasPermission = await checkMicrophonePermission()
        guard hasPermission else {
            print("❌ Microphone permission denied or not granted")
            let message = PermissionsManager.shared.microphonePermissionMessage()
            throw RecordingError.permissionDenied
        }
        
        // Start countdown
        await MainActor.run {
            recordingState = .countdown(3)
        }
        
        // Countdown: 3, 2, 1
        for count in (1...3).reversed() {
            await MainActor.run {
                recordingState = .countdown(count)
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Now actually start recording
        try await actuallyStartRecording()
    }
    
    // MARK: - Actually Start Recording (internal)
    private func actuallyStartRecording() async throws {
        print("🎙️ Configuring audio session for recording...")
        
        // Configure audio session for recording BEFORE creating recorder
        do {
            // CRITICAL: Fully reset audio session to fix permission issues
            // This ensures the session is in a clean state
            do {
                // First, try to deactivate with notification
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                print("✅ Audio session deactivated")
            } catch {
                // If that fails, try without options
                try? audioSession.setActive(false)
                print("ℹ️ Audio session deactivated (fallback)")
            }
            
            // Wait longer to ensure deactivation completes
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Reset category to default first (helps with permission issues)
            do {
                try audioSession.setCategory(.soloAmbient, mode: .default)
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            } catch {
                print("ℹ️ Category reset note: \(error.localizedDescription)")
            }
            
            // Check if audio session is already active
            if audioSession.isOtherAudioPlaying {
                print("⚠️ Other audio is playing - will interrupt for recording")
            }
            
            // Set category for recording with proper options
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            print("✅ Audio session category set to .playAndRecord")
            
            // Activate session for recording
            // Use .notifyOthersOnDeactivation when activating to properly handle conflicts
            try audioSession.setActive(true, options: [])
            print("✅ Audio session activated for recording")
            
            // Verify the session is properly configured
            let currentCategory = audioSession.category
            let isActive = audioSession.isOtherAudioPlaying
            let isInputAvailable = audioSession.isInputAvailable
            print("📊 Audio session state - Category: \(currentCategory.rawValue), Other audio playing: \(isActive), Input available: \(isInputAvailable)")
            
            // Verify input is available
            guard isInputAvailable else {
                print("❌ Audio input is not available on this device")
                try? restorePlaybackAudioSession()
                await MainActor.run {
                    recordingState = .idle
                }
                throw RecordingError.audioSessionError("Microphone input is not available")
            }
            
        } catch let error as RecordingError {
            // Re-throw our custom errors
            await MainActor.run {
                recordingState = .idle
            }
            throw error
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
            print("   Error details: \(error)")
            
            // Try to restore playback session on error
            try? restorePlaybackAudioSession()
            await MainActor.run {
                recordingState = .idle
            }
            throw RecordingError.audioSessionError(error.localizedDescription)
        }
        
        // Create temporary file URL
        let tempDir = fileManager.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL
        
        // Audio settings for M4A/AAC format
        // Note: AVLinearPCM* keys are only for PCM format, not AAC
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        print("🎙️ Recording settings: Format=M4A, SampleRate=44100, Channels=1, Quality=Medium, BitRate=128kbps")
        
        // Create recorder
        do {
            print("🎙️ Creating AVAudioRecorder with settings...")
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            print("✅ AVAudioRecorder created successfully")
            
            // Prepare to record - this validates the settings
            guard audioRecorder?.prepareToRecord() ?? false else {
                print("❌ Failed to prepare recorder - prepareToRecord() returned false")
                // Restore audio session for playback
                try? restorePlaybackAudioSession()
                await MainActor.run {
                    recordingState = .idle
                }
                throw RecordingError.failedToStart
            }
            
            print("✅ Recorder prepared successfully")
            
            // Start recording
            let success = audioRecorder?.record() ?? false
            guard success else {
                print("❌ Recorder returned false for record() - recording failed to start")
                // Restore audio session for playback
                try? restorePlaybackAudioSession()
                await MainActor.run {
                    recordingState = .idle
                }
                throw RecordingError.failedToStart
            }
            
            print("✅ Recording started successfully")
            
            // Update state
            await MainActor.run {
                recordingState = .recording
                recordingDuration = 0
            }
            
            // Start timers
            startTimers()
            
            print("✅ Started recording to: \(fileURL.path)")
        } catch {
            print("❌ Failed to start recording: \(error.localizedDescription)")
            print("   Error details: \(error)")
            // Restore audio session for playback
            try? restorePlaybackAudioSession()
            await MainActor.run {
                recordingState = .idle
            }
            throw RecordingError.failedToStart
        }
    }
    
    // MARK: - Restore Playback Audio Session
    private func restorePlaybackAudioSession() throws {
        try audioSession.setActive(false)
        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
        try audioSession.setActive(true)
    }
    
    // MARK: - Stop Recording
    func stopRecording() async throws -> RecordingResult {
        guard let recorder = audioRecorder else {
            throw RecordingError.notRecording
        }
        
        guard let fileURL = recordingURL else {
            throw RecordingError.noFileURL
        }
        
        // Update state
        await MainActor.run {
            recordingState = .processing
        }
        
        // Get duration from our timer BEFORE stopping (more accurate)
        let duration = await MainActor.run {
            recordingDuration
        }
        
        // Stop recording
        recorder.stop()
        stopTimers()
        
        // Restore audio session for playback
        do {
            try restorePlaybackAudioSession()
            print("✅ Audio session restored for playback")
        } catch {
            print("⚠️ Failed to restore playback audio session: \(error)")
        }
        
        // Analyze audio levels
        let (averageLevel, peakLevel) = await analyzeAudioLevels()
        
        // Get file size
        let fileSize = getFileSize(at: fileURL)
        
        // Create result
        let result = RecordingResult(
            fileURL: fileURL,
            videoURL: nil,
            duration: duration,
            fileSize: fileSize,
            averageLevel: averageLevel,
            peakLevel: peakLevel
        )
        
        // Update state
        await MainActor.run {
            recordingState = .completed
            recordingDuration = duration
        }
        
        // Clean up
        audioRecorder = nil
        
        print("✅ Recording stopped. Duration: \(String(format: "%.2f", duration))s, Size: \(fileSize) bytes")
        
        return result
    }

    // MARK: - Process Video Import
    func processVideoImport(videoURL: URL) async throws -> RecordingResult {
        await MainActor.run {
            recordingState = .processing
            recordingDuration = 0
            audioLevel = 0.0
        }

        do {
            let extractionResult = try await VideoProcessingService.shared.extractAudio(from: videoURL)
            let result = RecordingResult(
                fileURL: extractionResult.audioURL,
                videoURL: extractionResult.videoURL,
                duration: extractionResult.duration,
                fileSize: extractionResult.fileSize,
                averageLevel: 0.0,
                peakLevel: 0.0
            )

            await MainActor.run {
                recordingState = .completed
                recordingDuration = extractionResult.duration
            }

            return result
        } catch {
            let message = "Failed to process video: \(error.localizedDescription)"
            await MainActor.run {
                recordingState = .error(message)
            }
            throw error
        }
    }
    
    // MARK: - Cancel Recording
    func cancelRecording() {
        audioRecorder?.stop()
        stopTimers()
        
        // Restore audio session for playback
        try? restorePlaybackAudioSession()
        
        // Delete temporary file
        if let fileURL = recordingURL {
            try? fileManager.removeItem(at: fileURL)
        }
        
        recordingURL = nil
        audioRecorder = nil
        
        Task { @MainActor in
            recordingState = .idle
            recordingDuration = 0
            audioLevel = 0.0
        }
        
        print("🚫 Recording cancelled")
    }
    
    // MARK: - Reset Recording State
    func reset() {
        Task { @MainActor in
            recordingState = .idle
            recordingDuration = 0
            audioLevel = 0.0
        }
        recordingURL = nil
        audioRecorder = nil
        stopTimers()
        print("🔄 Recording state reset")
    }
    
    // MARK: - Timers
    private func startTimers() {
        // Ensure timers run on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Duration timer - update every 0.2 seconds (optimized from 0.1s for better performance)
            // Still smooth enough for UI while reducing updates by 2x
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if case .recording = self.recordingState {
                    self.recordingDuration += 0.2
                }
            }
            
            // Level meter timer - update every 0.2 seconds (optimized from 0.05s for better performance)
            // Reduces updates by 4x (from 20/sec to 5/sec) while maintaining smooth visualization
            self.levelTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.audioRecorder?.updateMeters()
                
                // Get average power (returns dB, typically -160 to 0)
                // Convert Float to Double
                let averagePower = Double(self.audioRecorder?.averagePower(forChannel: 0) ?? -160.0)
                
                // Convert to linear scale (0.0 to 1.0)
                // Normalize: -60dB to 0dB maps to 0.0 to 1.0
                let normalizedLevel = max(0.0, min(1.0, (averagePower + 60.0) / 60.0))
                
                self.audioLevel = normalizedLevel
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    // MARK: - Audio Analysis
    private func analyzeAudioLevels() async -> (average: Double, peak: Double) {
        // For now, return the current levels
        // In a full implementation, we could analyze the entire file
        let avg = audioLevel
        let peak = audioLevel // Simplified - could analyze file for true peak
        
        return (avg, peak)
    }
    
    // MARK: - File Size
    private func getFileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
    
    // MARK: - Format Duration
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                recordingState = .error("Recording failed")
            }
            print("❌ Recording finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            recordingState = .error(error?.localizedDescription ?? "Unknown error")
        }
        print("❌ Recording error: \(error?.localizedDescription ?? "Unknown")")
    }
}

// MARK: - Recording Errors
enum RecordingError: LocalizedError {
    case permissionDenied
    case failedToStart
    case notRecording
    case noFileURL
    case processingFailed
    case audioSessionError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record sounds. Please enable microphone access in Settings."
        case .failedToStart:
            return "Failed to start recording. Please ensure your device's microphone is working and try again."
        case .notRecording:
            return "No recording in progress."
        case .noFileURL:
            return "Recording file not found."
        case .processingFailed:
            return "Failed to process recording."
        case .audioSessionError(let message):
            return "Audio session error: \(message). Please try again."
        }
    }
}

