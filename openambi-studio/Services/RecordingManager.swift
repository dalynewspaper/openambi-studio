import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
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
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - Permission Check
    func checkMicrophonePermission() async -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await requestMicrophonePermission()
        @unknown default:
            return false
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Start Recording
    func startRecording() async throws {
        // Check permission
        guard await checkMicrophonePermission() else {
            throw RecordingError.permissionDenied
        }
        
        // Configure audio session for recording BEFORE creating recorder
        do {
            // Deactivate current session first to allow reconfiguration
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Set category for recording with proper options
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Activate session for recording
            try audioSession.setActive(true)
            
            print("✅ Audio session configured for recording")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            throw RecordingError.failedToStart
        }
        
        // Create temporary file URL
        let tempDir = fileManager.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL
        
        // Audio settings - ensure all required keys are present
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 128000,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        // Create recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Prepare to record - this validates the settings
            guard audioRecorder?.prepareToRecord() ?? false else {
                print("❌ Failed to prepare recorder")
                throw RecordingError.failedToStart
            }
            
            // Start recording
            let success = audioRecorder?.record() ?? false
            guard success else {
                print("❌ Recorder returned false for record()")
                throw RecordingError.failedToStart
            }
            
            // Update state
            await MainActor.run {
                recordingState = .recording
                recordingDuration = 0
            }
            
            // Start timers
            startTimers()
            
            print("✅ Started recording to: \(fileURL.path)")
        } catch {
            print("❌ Failed to start recording: \(error)")
            // Restore audio session for playback
            try? restorePlaybackAudioSession()
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
            
            // Duration timer - update every 0.1 seconds
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if case .recording = self.recordingState {
                    self.recordingDuration += 0.1
                }
            }
            
            // Level meter timer - update every 0.05 seconds for smooth visualization
            self.levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
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
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record sounds."
        case .failedToStart:
            return "Failed to start recording. Please try again."
        case .notRecording:
            return "No recording in progress."
        case .noFileURL:
            return "Recording file not found."
        case .processingFailed:
            return "Failed to process recording."
        }
    }
}

