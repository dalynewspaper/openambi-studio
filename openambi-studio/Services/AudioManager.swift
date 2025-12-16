import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
import MediaPlayer

class AudioManager: ObservableObject {
    @Published var isPlaying = false
    @Published var masterVolume: Double = 1.0 // Set to 1.0 (100%) for full volume
    
    // Use AVQueuePlayer for streaming support from remote URLs with seamless looping
    var audioPlayers: [UUID: AVQueuePlayer] = [:]
    private var playerLooper: [UUID: AVPlayerLooper] = [:]
    @Published var tracks: [AudioTrack] = []
    private var audioSessionConfigured = false
    
    // Audio cache service for local file caching
    private let cacheService = AudioCacheService.shared
    
    // Performance optimizer
    private let performanceOptimizer = PerformanceOptimizer.shared
    private let lazyLoader = LazyTrackLoader.shared
    
    // Retry tracking for failed loads
    private var retryCounts: [UUID: Int] = [:]
    private let maxRetries = 3
    private var statusObservers: [UUID: NSKeyValueObservation] = [:]
    private var interruptionObserver: NSObjectProtocol?
    
    // Remote command center setup tracking
    private var commandCenterSetup = false
    private var playHandler: Any?
    private var pauseHandler: Any?
    private var toggleHandler: Any?
    private var stopHandler: Any?
    
    // Audio session setup synchronization
    private let audioSessionQueue = DispatchQueue(label: "com.openambi.audiosession", qos: .userInitiated)
    private var isSettingUpAudioSession = false
    
    // Frequency generator for frequency-based tracks
    private let frequencyGenerator = FrequencyGenerator()
    
    init() {
        // Don't set up audio session in init - defer to first use
        // This prevents crashes on launch
        
        // Listen for audio session interruptions
        setupInterruptionObserver()
        
        // Set up remote command center once on initialization
        setupRemoteCommandCenter()
    }
    
    
    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
            switch type {
            case .began:
                print("⚠️ Audio session interrupted")
                // Optionally pause playback
            case .ended:
                print("✅ Audio session interruption ended")
                // Reactivate audio session and resume if needed
                self.setupAudioSession()
                // Retry any failed players
                self.retryFailedPlayers()
            @unknown default:
                break
            }
        }
    }
    
    private func retryFailedPlayers() {
        // Retry loading any tracks that failed
        for track in tracks where track.isActive {
            if audioPlayers[track.id] == nil {
                print("🔄 Retrying failed track: \(track.name)")
                retryCounts[track.id] = 0 // Reset retry count
                // Capture track before Task to avoid concurrency issues
                let trackToPreload = track
                Task {
                    await preloadTrackImmediately(trackToPreload)
                }
            }
        }
    }
    
    private func setupAudioSession() {
        // Prevent concurrent setup calls
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Prevent concurrent setups
            guard !self.isSettingUpAudioSession else {
                return
            }
            
            // Quick check: if already configured, skip
            if self.audioSessionConfigured {
                return
            }
            
            self.isSettingUpAudioSession = true
            
            do {
                // Configure audio session for background playback
                let audioSession = AVAudioSession.sharedInstance()
                
                // Always set category - it's safe to call multiple times
                // Use .playback category for audio playback
                // .mixWithOthers allows mixing with other audio apps
                // .allowAirPlay allows streaming to AirPlay devices
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
                
                // Activate the session - safe to call even if already active
                // Don't use options when activating - that's only for deactivation
                try audioSession.setActive(true)
                
                self.audioSessionConfigured = true
                let categoryValue = audioSession.category.rawValue
                let modeValue = audioSession.mode.rawValue
                let otherAudioPlaying = audioSession.isOtherAudioPlaying
                DispatchQueue.main.async {
                    print("✅ Audio session configured successfully")
                    print("   Category: \(categoryValue)")
                    print("   Mode: \(modeValue)")
                    print("   Other audio playing: \(otherAudioPlaying)")
                }
            } catch {
                let errorDescription = error.localizedDescription
                let nsError = error as NSError
                let errorCode = nsError.code
                let errorDomain = nsError.domain
                DispatchQueue.main.async {
                    print("❌ Failed to set up audio session: \(error)")
                    print("   Error details: \(errorDescription)")
                    print("   Error code: \(errorCode)")
                    print("   Error domain: \(errorDomain)")
                }
                // Don't mark as configured so we can try again
                self.audioSessionConfigured = false
            }
            
            self.isSettingUpAudioSession = false
        }
    }
    
    func loadTracks(_ tracks: [AudioTrack]) {
        // Stop all current playback first
        stopAll()
        
        // Get IDs of new tracks to ensure we don't keep any old user recordings
        let newTrackIds = Set(tracks.map { $0.id })
        
        // Remove any old user recordings that aren't in the new list
        // This prevents deleted recordings from persisting across app restarts
        let oldUserRecordings = self.tracks.filter { $0.isUserRecording && !newTrackIds.contains($0.id) }
        if !oldUserRecordings.isEmpty {
            print("🗑️ Removing \(oldUserRecordings.count) old user recordings that are no longer in database")
            let deletedIds = Set(oldUserRecordings.map { $0.id })
            
            for oldRecording in oldUserRecordings {
                // Stop and clean up any active old recordings
                if oldRecording.isActive {
                    toggleTrack(oldRecording.id, isActive: false)
                }
                // Remove from players
                audioPlayers.removeValue(forKey: oldRecording.id)
                playerLooper.removeValue(forKey: oldRecording.id)
            }
            
            // Also remove from saved mix state to prevent restoration
            StatePersistenceService.shared.removeTracksFromSavedMix(deletedIds)
        }
        
        // Filter saved mix to only include tracks that still exist
        StatePersistenceService.shared.filterSavedMixToValidTracks(newTrackIds)
        
        // Replace all tracks with the new list
        self.tracks = tracks
        
        // Don't preload all tracks immediately - we'll preload active ones first
        // Inactive tracks will be loaded lazily when needed
    }
    
    /// Remove all user recordings from the tracks list (keeps ambient sounds and frequency tracks)
    func removeUserRecordings() {
        let originalCount = tracks.count
        let nonUserTracks = tracks.filter { !$0.isUserRecording }
        let removedCount = originalCount - nonUserTracks.count
        
        // Stop any active user recordings
        for track in tracks where track.isUserRecording && track.isActive {
            toggleTrack(track.id, isActive: false)
        }
        
        // Update tracks to exclude user recordings
        self.tracks = nonUserTracks
        print("🗑️ Removed \(removedCount) user recordings from AudioManager")
        
        // Update Now Playing info when tracks are loaded
        updateNowPlayingInfo()
    }
    
    /// Remove a specific track by ID (used when deleting a recording)
    func removeTrack(_ trackId: UUID) {
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else {
            print("⚠️ Track \(trackId) not found in AudioManager")
            return
        }
        
        // Stop the track if it's playing
        if tracks[index].isActive {
            toggleTrack(trackId, isActive: false)
        }
        
        // Remove from tracks
        tracks.remove(at: index)
        print("🗑️ Removed track \(trackId) from AudioManager")
        
        // Update Now Playing info
        updateNowPlayingInfo()
    }
    
    // Preload a track immediately and wait for it to be ready
    func preloadTrackImmediately(_ track: AudioTrack) async {
        // Ensure audio session is set up
        setupAudioSession()
        
        // Check cache first - if not cached, download in background while setting up player
        let finalURL: URL
        
        if let cachedURL = cacheService.getCachedFileURL(for: track.audioUrl) {
            // Use cached file - instant playback!
            finalURL = cachedURL
            print("✅ Using cached file for \(track.name)")
        } else {
            // Not cached - use remote URL for now, but start downloading in background
            guard let remoteURL = URL(string: track.audioUrl) else {
                print("❌ Invalid URL for track: \(track.name) - \(track.audioUrl)")
                return
            }
            finalURL = remoteURL
            
            // Start downloading in background (non-blocking)
            // Capture values before Task to avoid concurrency issues
            let audioUrl = track.audioUrl
            let trackName = track.name
            Task.detached(priority: .userInitiated) {
                do {
                    _ = try await AudioCacheService.shared.downloadAndCache(audioUrl, priority: .high)
                    print("✅ Background cached \(trackName) for next time")
                } catch {
                    print("⚠️ Failed to cache \(trackName): \(error.localizedDescription)")
                }
            }
        }
        
        // Use AVQueuePlayer with cached or remote URL
        let playerItem = AVPlayerItem(url: finalURL)
        
        // Apply optimized buffer settings based on cache status
        let isCached = cacheService.isCached(track.audioUrl)
        let bufferConfig = performanceOptimizer.bufferConfig(for: track, isCached: isCached)
        performanceOptimizer.applyBufferOptimization(to: playerItem, config: bufferConfig)
        
        // Add error observer for player item
        let trackId = track.id
        let trackName = track.name
        let trackToRetry = track
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Player item failed to play \(trackName): \(error.localizedDescription)")
                // Retry if not exceeded max retries
                let currentRetries = self.retryCounts[trackId] ?? 0
                if currentRetries < self.maxRetries {
                    self.retryCounts[trackId] = currentRetries + 1
                    let delay = Double(currentRetries + 1) * 1.0
                    print("🔄 Retrying \(trackName) in \(delay)s")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self = self else { return }
                        Task { @MainActor in
                            await self.preloadTrackImmediately(trackToRetry)
                        }
                    }
                }
            }
        }
        
        // Add status observer for player item
        let trackIdForObserver = track.id
        let trackNameForObserver = track.name
        let trackToRetryForObserver = track
        let statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            switch item.status {
            case .readyToPlay:
                print("✅ \(trackNameForObserver) player item ready")
                self.retryCounts[trackIdForObserver] = 0 // Reset on success
            case .failed:
                let error = item.error?.localizedDescription ?? "Unknown error"
                print("❌ \(trackNameForObserver) player item failed: \(error)")
                let currentRetries = self.retryCounts[trackIdForObserver] ?? 0
                if currentRetries < self.maxRetries {
                    self.retryCounts[trackIdForObserver] = currentRetries + 1
                    let delay = Double(currentRetries + 1) * 1.0
                    print("🔄 Retrying \(trackNameForObserver) in \(delay)s (attempt \(currentRetries + 1)/\(self.maxRetries))")
                    let trackId = trackIdForObserver
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self = self else { return }
                        // Clean up failed player
                        self.audioPlayers[trackId]?.pause()
                        self.audioPlayers.removeValue(forKey: trackId)
                        self.playerLooper[trackId]?.disableLooping()
                        self.playerLooper.removeValue(forKey: trackId)
                        Task { @MainActor in
                            await self.preloadTrackImmediately(trackToRetryForObserver)
                        }
                    }
                } else {
                    print("❌ \(trackNameForObserver) failed after \(self.maxRetries) retries")
                }
            case .unknown:
                print("⚠️ \(trackNameForObserver) player item status unknown")
            @unknown default:
                break
            }
        }
        
        // Store observer
        await MainActor.run {
            statusObservers[track.id] = statusObserver
        }
        
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.automaticallyWaitsToMinimizeStalling = false // Start immediately
        
        // Set initial volume
        let initialVolume = track.isActive ? max(0.01, track.volume) : 0.0
        queuePlayer.volume = Float(initialVolume * masterVolume)
        
        // Create looper for seamless looping
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        await MainActor.run {
            audioPlayers[track.id] = queuePlayer
            playerLooper[track.id] = looper
        }
        
        // Don't wait for full buffer - start playing immediately if track is active
        // This allows instant playback even if buffer isn't full
        if track.isActive {
            await MainActor.run {
                // Start playing immediately without waiting for full buffer
                queuePlayer.playImmediately(atRate: 1.0)
                print("▶️ Started \(track.name) immediately (buffering in background)")
            }
        }
        
        print("✅ Preloaded: \(track.name)")
    }
    
    // Wait for player to be ready
    private func waitForPlayerReady(_ player: AVQueuePlayer, trackName: String) async {
        // If already ready, return immediately
        if player.status == .readyToPlay {
            return
        }
        
        // Wait for ready status using async continuation
        await withCheckedContinuation { continuation in
            var hasResumed = false
            var observer: NSKeyValueObservation?
            var timeoutWorkItem: DispatchWorkItem?
            
            // Helper to safely resume only once
            let resumeOnce: () -> Void = {
                guard !hasResumed else { return }
                hasResumed = true
                observer?.invalidate()
                timeoutWorkItem?.cancel()
                continuation.resume()
            }
            
            observer = player.observe(\.status, options: [.new]) { player, _ in
                if player.status == .readyToPlay {
                    resumeOnce()
                } else if player.status == .failed {
                    print("❌ Player failed to load: \(trackName)")
                    resumeOnce()
                }
            }
            
            // Timeout after 2 seconds
            timeoutWorkItem = DispatchWorkItem {
                resumeOnce()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeoutWorkItem!)
        }
    }
    
    // Start a track immediately when ready (non-blocking)
    func startTrackImmediately(_ trackId: UUID, volume: Double) async {
        guard let player = audioPlayers[trackId] else {
            print("⚠️ Player not found for track: \(trackId)")
            return
        }
        
        // Don't wait for buffer - start playing immediately
        await MainActor.run {
            // Set volume and play immediately
            let targetVolume = Float(volume * masterVolume)
            player.volume = targetVolume
            
            // Use playImmediately for instant start, even if buffer isn't full
            if player.status == .readyToPlay || player.status == .unknown {
                player.playImmediately(atRate: 1.0)
            } else {
                player.play() // Will start when buffer is ready
            }
            
            print("▶️ Started playback immediately for track: \(trackId), volume: \(targetVolume), status: \(player.status.rawValue)")
        }
    }
    
    func preloadTrack(_ track: AudioTrack) {
        // Ensure audio session is set up before loading tracks
        setupAudioSession()
        
        Task {
            // Check cache first
            let finalURL: URL
            
            if let cachedURL = cacheService.getCachedFileURL(for: track.audioUrl) {
                // Use cached file
                finalURL = cachedURL
                print("✅ Using cached file for \(track.name)")
            } else {
                // Not cached - use remote URL
                guard let remoteURL = URL(string: track.audioUrl) else {
                    print("❌ Invalid URL for track: \(track.name) - \(track.audioUrl)")
                    return
                }
                finalURL = remoteURL
                print("🔗 Loading audio from URL: \(remoteURL.absoluteString)")
                
                // Start downloading in background for next time
                // Capture only the values we need to avoid concurrency issues
                let audioUrlString = track.audioUrl
                let trackName = track.name
                let cacheService = self.cacheService
                Task.detached(priority: .utility) {
                    do {
                        _ = try await cacheService.downloadAndCache(audioUrlString, priority: .low)
                        print("✅ Background cached \(trackName)")
                    } catch {
                        print("⚠️ Failed to cache \(trackName): \(error.localizedDescription)")
                    }
                }
            }
            
            // Use AVQueuePlayer with cached or remote URL
            let playerItem = AVPlayerItem(url: finalURL)
            
            // Apply optimized buffer settings
            let isCached = cacheService.isCached(track.audioUrl)
            let bufferConfig = performanceOptimizer.bufferConfig(for: track, isCached: isCached)
            performanceOptimizer.applyBufferOptimization(to: playerItem, config: bufferConfig)
            
            // Add error observer to catch loading issues
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("❌ Failed to play \(track.name): \(error.localizedDescription)")
                }
            }
            
            // Add status observer with retry logic
            let statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self = self else { return }
                
                switch item.status {
                case .readyToPlay:
                    print("✅ \(track.name) player item is ready to play")
                    // Reset retry count on success
                    self.retryCounts[track.id] = 0
                case .failed:
                    let error = item.error?.localizedDescription ?? "Unknown error"
                    print("❌ \(track.name) player item failed: \(error)")
                    
                    // Retry loading if we haven't exceeded max retries
                    let currentRetries = self.retryCounts[track.id] ?? 0
                    if currentRetries < self.maxRetries {
                        self.retryCounts[track.id] = currentRetries + 1
                        let delay = Double(currentRetries + 1) * 1.0 // Exponential backoff: 1s, 2s, 3s
                        print("🔄 Retrying \(track.name) in \(delay)s (attempt \(currentRetries + 1)/\(self.maxRetries))")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                            guard let self = self else { return }
                            // Clean up failed player
                            self.audioPlayers[track.id]?.pause()
                            self.audioPlayers.removeValue(forKey: track.id)
                            self.playerLooper[track.id]?.disableLooping()
                            self.playerLooper.removeValue(forKey: track.id)
                            
                            // Retry loading - capture track before Task
                            let trackToRetry = track
                            Task {
                                await self.preloadTrackImmediately(trackToRetry)
                            }
                        }
                    } else {
                        print("❌ \(track.name) failed after \(self.maxRetries) retries. Check network connection.")
                    }
                case .unknown:
                    print("⚠️ \(track.name) player item status unknown")
                @unknown default:
                    print("⚠️ \(track.name) player item status: \(item.status.rawValue)")
                }
            }
            
            // Store observer to keep it alive and allow cleanup
            statusObservers[track.id] = statusObserver
            // Store observer to keep it alive (observation stops when observer is deallocated)
            _ = statusObserver
            
            // Buffer settings already applied via performanceOptimizer
            
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            
            // Set volume (0.0 to 1.0) - start at 0 for inactive tracks
            // But ensure minimum volume if track should be active
            let initialVolume = track.isActive ? max(0.01, track.volume) : 0.0
            queuePlayer.volume = Float(initialVolume * masterVolume)
            
            print("🔊 Initial volume for \(track.name): track=\(Int(track.volume * 100))%, master=\(Int(masterVolume * 100))%, player=\(queuePlayer.volume)")
            
            // Create a looper for seamless looping
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            
            await MainActor.run {
                audioPlayers[track.id] = queuePlayer
                playerLooper[track.id] = looper
                
                // Configure for instant playback
                queuePlayer.automaticallyWaitsToMinimizeStalling = false
                
                print("✅ Preloaded track: \(track.name) from \(finalURL.absoluteString)")
                
                // Start buffering immediately for faster playback
                // Only preroll when player is ready (prevents crash)
                // Use a small delay to ensure player item is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if queuePlayer.status == .readyToPlay {
                        // Only preroll if track is active (to reduce warnings for inactive tracks)
                        if track.isActive {
                            queuePlayer.preroll(atRate: 1.0) { success in
                                if success {
                                    print("🎵 Track \(track.name) is ready to play")
                                }
                                // Silently fail - preroll is optional for remote streams
                            }
                        }
                    } else {
                        // Wait for ready status using KVO
                        var observer: NSKeyValueObservation?
                        observer = queuePlayer.observe(\.status, options: [.new]) { player, _ in
                            if player.status == .readyToPlay {
                                // Only preroll if track is active
                                if track.isActive {
                                    player.preroll(atRate: 1.0) { success in
                                        if success {
                                            print("🎵 Track \(track.name) is ready to play")
                                        }
                                        // Silently fail - preroll is optional for remote streams
                                    }
                                }
                                // Remove observer after first ready state
                                observer?.invalidate()
                            }
                        }
                    }
                }
                
                // Start playing if track is active (auto-play when dragged up)
                if track.isActive {
                    if !isPlaying {
                        isPlaying = true
                    }
                    
                    // Verify audio session is active
                    let audioSession = AVAudioSession.sharedInstance()
                    print("🔊 Audio session active: \(audioSession.isOtherAudioPlaying ? "mixing with other audio" : "exclusive"), category: \(audioSession.category.rawValue)")
                    
                    // Play immediately - use playImmediately for instant start
                    if queuePlayer.status == .readyToPlay || queuePlayer.status == .unknown {
                        queuePlayer.playImmediately(atRate: 1.0)
                    } else {
                        queuePlayer.play() // Will start when buffer is ready
                    }
                    print("▶️ Called play() for \(track.name), rate: \(queuePlayer.rate), volume: \(queuePlayer.volume)")
                }
            }
        }
    }
    
    private func loadTrack(_ track: AudioTrack) {
        // This is now just an alias for preloadTrack
        preloadTrack(track)
    }
    
    func updateTrackVolume(_ trackId: UUID, volume: Double) {
        // Clamp volume to valid range
        let clampedVolume = max(0.0, min(1.0, volume))
        
        // Update track volume in array - ensure we're updating the correct track
        guard let index = tracks.firstIndex(where: { $0.id == trackId }) else {
            print("⚠️ updateTrackVolume: Track not found in array: \(trackId)")
            return
        }
        
        // Double-check that we found the right track
        guard tracks[index].id == trackId else {
            print("⚠️ updateTrackVolume: Track ID mismatch! Expected \(trackId), found \(tracks[index].id)")
            return
        }
        
        let track = tracks[index]
        
        // Only update if volume actually changed (avoid unnecessary state updates)
        let oldVolume = track.volume
        let volumeChanged = abs(oldVolume - clampedVolume) >= 0.001
        
        // Update track volume in array (always update state, even if player doesn't exist yet)
        let trackName = track.name
        if volumeChanged {
            tracks[index].volume = clampedVolume
        }
        
        // Handle frequency tracks
        if track.isFrequencyTrack {
            let floatVolume = Float(clampedVolume * masterVolume)
            frequencyGenerator.updateVolume(trackId: trackId, volume: floatVolume)
            
            if volumeChanged {
                print("🔊 updateTrackVolume (frequency): \(trackName) → \(Int(clampedVolume * 100))%")
                if abs(oldVolume - clampedVolume) >= 0.05 {
                    updateNowPlayingInfo()
                }
            }
            return
        }
        
        // Update player if it exists
        guard let player = audioPlayers[trackId] else {
            // Player doesn't exist yet - volume will be applied when player is created
            if volumeChanged {
                print("🔊 updateTrackVolume: \(trackName) (ID: \(trackId.uuidString.prefix(8))) → \(Int(clampedVolume * 100))% (player not loaded yet)")
            }
            return
        }
        
        // Calculate target volume with master volume
        let targetVolume = Float(clampedVolume * masterVolume)
        
        // CRITICAL: Always update player volume, even if small change
        player.volume = targetVolume
        
        // Debug logging for volume updates (can be removed in production)
        if volumeChanged {
            print("🔊 updateTrackVolume: \(trackName) (ID: \(trackId.uuidString.prefix(8))) → \(Int(clampedVolume * 100))%")
            
            // Update Now Playing info when volume changes significantly (>5%)
            if abs(oldVolume - clampedVolume) >= 0.05 {
                updateNowPlayingInfo()
            }
        }
        
        // If volume is > 0 and track is active, ensure it's playing
        if clampedVolume > 0.01 && tracks[index].isActive {
            if player.rate == 0 {
                print("🔊 Volume > 0 but not playing, starting playback for: \(tracks[index].name)")
                player.volume = targetVolume // Set volume before playing
                player.play()
            }
        } else {
            // Volume is 0 OR track is not active - pause the player
            if player.rate > 0 {
                print("⏸️ Pausing player for \(tracks[index].name) (volume=0 or inactive)")
                player.pause()
            }
        }
    }
    
    func updateMasterVolume(_ volume: Double) {
        masterVolume = volume
        for (trackId, player) in audioPlayers {
            if let track = tracks.first(where: { $0.id == trackId }) {
                player.volume = Float(track.volume * masterVolume)
            }
        }
        
        // Update frequency tracks volume
        for track in tracks where track.isFrequencyTrack && track.isActive {
            let floatVolume = Float(track.volume * masterVolume)
            frequencyGenerator.updateVolume(trackId: track.id, volume: floatVolume)
        }
        
        updateWidget()
        // Update Now Playing info when master volume changes
        updateNowPlayingInfo()
    }
    
    // MARK: - Frequency Track Handling
    
    private func handleFrequencyTrackToggle(trackId: UUID, track: AudioTrack, isActive: Bool) {
        guard let preset = track.frequencyPreset else {
            print("⚠️ Frequency track missing preset: \(track.name)")
            return
        }
        
        if isActive {
            // Ensure audio session is active
            setupAudioSession()
            
            // Auto-start playing when track is activated
            if !isPlaying {
                isPlaying = true
                DispatchQueue.main.async {
                    UIApplication.shared.beginReceivingRemoteControlEvents()
                }
            }
            
            // Start frequency generation
            let volume = Float(max(0.01, track.volume) * masterVolume)
            frequencyGenerator.startFrequency(
                trackId: trackId,
                type: preset.frequencyType,
                volume: volume
            )
            
            print("🎵 Started frequency track: \(track.name), preset: \(preset.rawValue), volume: \(volume)")
            
            // Update Now Playing info
            updateNowPlayingInfo()
        } else {
            // Stop frequency generation
            frequencyGenerator.stopFrequency(trackId: trackId)
            print("⏸️ Stopped frequency track: \(track.name)")
            
            // Update Now Playing info
            updateNowPlayingInfo()
        }
    }
    
    func toggleTrack(_ trackId: UUID, isActive: Bool) {
        // Check current state to avoid unnecessary updates
        guard let currentIndex = tracks.firstIndex(where: { $0.id == trackId }) else {
            print("⚠️ toggleTrack: Track not found: \(trackId)")
            return
        }
        let wasActive = tracks[currentIndex].isActive
        let trackName = tracks[currentIndex].name
        let track = tracks[currentIndex]
        
        // Only proceed if state is actually changing
        guard wasActive != isActive else {
            print("⚠️ toggleTrack: State unchanged for \(trackName) (wasActive=\(wasActive), isActive=\(isActive))")
            return
        }
        
        print("🔄 toggleTrack: \(trackName) - \(wasActive ? "ON" : "OFF") → \(isActive ? "ON" : "OFF")")
        
        // Update track state
        tracks[currentIndex].isActive = isActive
        
        // Handle frequency tracks differently
        if track.isFrequencyTrack {
            handleFrequencyTrackToggle(trackId: trackId, track: track, isActive: isActive)
            return
        }
        
        // Check if player exists
        guard let player = audioPlayers[trackId] else {
            // Player doesn't exist - need to preload the track first
            if let track = tracks.first(where: { $0.id == trackId }) {
                print("⚡ Player not found for \(track.name), preloading NOW...")
                // Preload the track immediately (non-blocking)
                // Capture track before Task to avoid concurrency issues
                let trackToPreload = track
                Task {
                    await preloadTrackImmediately(trackToPreload)
                    
                    // After preloading, activate the track immediately
                    await MainActor.run {
                        if let readyPlayer = self.audioPlayers[trackId] {
                            // Update track state
                            if let index = self.tracks.firstIndex(where: { $0.id == trackId }) {
                                self.tracks[index].isActive = isActive
                                
                                if isActive {
                                    let currentVolume = max(0.01, self.tracks[index].volume)
                                    let targetVolume = Float(currentVolume * self.masterVolume)
                                    readyPlayer.volume = targetVolume
                                    
                                    // Use playImmediately for instant start
                                    if readyPlayer.status == .readyToPlay {
                                        readyPlayer.playImmediately(atRate: 1.0)
                                    } else {
                                        readyPlayer.play() // Will start as soon as buffer is ready
                                    }
                                    
                                    if !self.isPlaying {
                                        self.isPlaying = true
                                    }
                                    print("✅ Preloaded and started: \(track.name), volume: \(targetVolume)")
                                }
                            }
                        }
                    }
                }
            }
            return
        }
        
        // Clean up observers when deactivating (but keep player for quick reactivation)
        if !isActive {
            // Don't remove observers - we might reactivate soon
            // Just pause the player
        }
        
        if isActive {
            // Ensure audio session is active
            setupAudioSession()
            
            // Auto-start playing when track is activated
            if !isPlaying {
                isPlaying = true
                
                // Enable remote control now that app is fully initialized
                DispatchQueue.main.async {
                    UIApplication.shared.beginReceivingRemoteControlEvents()
                }
            }
            
            // Ensure volume is set correctly (must be > 0 to hear anything)
            let currentVolume = max(0.01, tracks[currentIndex].volume) // Minimum 1% to ensure audio plays
            let targetVolume = Float(currentVolume * masterVolume)
            
            // CRITICAL: Set volume BEFORE playing
            player.volume = targetVolume
            
            print("🔊 Activating track: \(tracks[currentIndex].name), track volume: \(Int(currentVolume * 100))%, master: \(Int(masterVolume * 100))%, player volume: \(targetVolume)")
            
            // Audio session is already set up by setupAudioSession()
            // No need to activate again here - it's handled in setupAudioSession()
            
            // Play immediately - don't wait for buffer
            // Use playImmediately for instant start, even if buffer isn't full
            if player.status == .readyToPlay || player.status == .unknown {
                // Start playing immediately - AVPlayer will buffer in background
                player.playImmediately(atRate: 1.0)
                print("▶️ Playing immediately: \(tracks[currentIndex].name), rate: \(player.rate)")
            } else {
                // Even if status is not ready, try to play - AVPlayer will start when ready
                player.play()
                print("▶️ Playing (buffering): \(tracks[currentIndex].name), status: \(player.status.rawValue), rate: \(player.rate)")
            }
            
            // Verify playback and volume after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Ensure volume is still set correctly
                let verifyVolume = Float(self.tracks[currentIndex].volume * self.masterVolume)
                if abs(player.volume - verifyVolume) > 0.01 {
                    print("⚠️ Volume mismatch! Setting player volume to: \(verifyVolume)")
                    player.volume = verifyVolume
                }
                
                if player.rate == 0 {
                    print("⚠️ Player not playing, retrying...")
                    player.volume = verifyVolume // Set volume again before retry
            player.play()
                } else {
                    print("✅ Player is playing: \(self.tracks[currentIndex].name), rate: \(player.rate), volume: \(player.volume)")
                }
            }
            
            // Update Now Playing info when track is activated
            updateNowPlayingInfo()
        } else {
            // Deactivate track - stop playback immediately
            let trackName = tracks[currentIndex].name
            print("⏸️ Deactivating track: \(trackName)")
            print("   Player rate before pause: \(player.rate)")
            
            // Stop playback immediately (no fade for instant response)
            player.pause()
            player.seek(to: .zero) // Reset to beginning
            player.volume = 0 // Reset volume
            
            print("✅ Track deactivated: \(trackName)")
            print("   Player rate after pause: \(player.rate)")
            print("   Player volume: \(player.volume)")
            
            // Update Now Playing info when track is deactivated
            updateNowPlayingInfo()
        }
    }
    
    func play() {
        // CRITICAL: Set up audio session FIRST and ensure it's active
        setupAudioSession()
        isPlaying = true
        
        // Enable remote control events for lock screen
        // This MUST be called before setting Now Playing info
        UIApplication.shared.beginReceivingRemoteControlEvents()
        // Note: setupRemoteCommandCenter() is now called in init() to prevent duplicate handlers
        
        // Play file-based tracks
        for (trackId, player) in audioPlayers {
            if let track = tracks.first(where: { $0.id == trackId }), track.isActive && track.volume > 0 {
                let volume = Float(track.volume * masterVolume)
                player.volume = volume
                // Use playImmediately for instant start
                if player.status == .readyToPlay || player.status == .unknown {
                    player.playImmediately(atRate: 1.0)
                } else {
                    player.play() // Will start when buffer is ready
                }
                print("▶️ Playing track: \(track.name), volume: \(volume)")
            }
        }
        
        // Resume or start frequency tracks
        for track in tracks where track.isFrequencyTrack && track.isActive && track.volume > 0 {
            guard let preset = track.frequencyPreset else {
                print("⚠️ Frequency track missing preset: \(track.name)")
                continue
            }
            // Start frequency if not already started, or resume if already started
            let volume = Float(track.volume * masterVolume)
            frequencyGenerator.startFrequency(
                trackId: track.id,
                type: preset.frequencyType,
                volume: volume
            )
            print("▶️ Started/resumed frequency track: \(track.name)")
        }
        
        // Update Now Playing info for lock screen
        // Use a small delay to ensure audio has actually started playing
        // iOS needs to detect actual audio playback before showing controls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.updateNowPlayingInfo()
        }
        
        // Also update immediately (in case delay isn't needed)
        updateNowPlayingInfo()
        
        // Update widget
        updateWidget()
    }
    
    func pause() {
        isPlaying = false
        for player in audioPlayers.values {
            player.pause()
        }
        
        // Pause frequency tracks
        for track in tracks where track.isFrequencyTrack && track.isActive {
            frequencyGenerator.pauseFrequency(trackId: track.id)
        }
        
        updateNowPlayingInfo()
        updateWidget()
    }
    
    private func updateWidget() {
        let activeTrackCount = tracks.filter { $0.isActive && $0.volume > 0 }.count
        WidgetUpdateService.shared.updateWidget(
            isPlaying: isPlaying,
            activeTrackCount: activeTrackCount,
            masterVolume: masterVolume
        )
    }
    
    // MARK: - Now Playing & Remote Controls
    
    private func setupRemoteCommandCenter() {
        // Prevent duplicate setup
        guard !commandCenterSetup else {
            return
        }
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        playHandler = commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        pauseHandler = commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        toggleHandler = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if let self = self {
                if self.isPlaying {
                    self.pause()
                } else {
                    self.play()
                }
            }
            return .success
        }
        
        // Stop command
        commandCenter.stopCommand.isEnabled = true
        stopHandler = commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stopAll()
            return .success
        }
        
        commandCenterSetup = true
        print("✅ Remote command center set up")
    }
    
    private func updateNowPlayingInfo() {
        // Ensure we're on the main thread - MPNowPlayingInfoCenter requires main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateNowPlayingInfo()
            }
            return
        }
        
        // CRITICAL: Ensure audio session is active before setting Now Playing info
        // iOS won't show lock screen controls if audio session isn't active
        let audioSession = AVAudioSession.sharedInstance()
        if !audioSession.isOtherAudioPlaying {
            do {
                try audioSession.setActive(true)
            } catch {
                print("⚠️ Failed to activate audio session for Now Playing: \(error)")
            }
        }
        
        let activeTracks = tracks.filter { $0.isActive && $0.volume > 0 }
        
        var nowPlayingInfo: [String: Any] = [:]
        
        if !activeTracks.isEmpty {
            // Create a combined title from active tracks
            let trackNames = activeTracks.map { $0.name }.joined(separator: " • ")
            nowPlayingInfo[MPMediaItemPropertyTitle] = trackNames
            nowPlayingInfo[MPMediaItemPropertyArtist] = "OpenAmbi"
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Ambient Soundscape"
            
            // CRITICAL: iOS requires a non-zero duration for lock screen controls to appear
            // For infinite/looping audio, use a large duration value
            // Setting duration to 0 tells iOS "no duration" and controls won't show
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 3600.0 // 1 hour (for infinite loops)
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
            
            // CRITICAL: Playback rate must be set correctly
            // Rate of 1.0 = playing, 0.0 = paused
            // If rate is 0 when audio is playing, iOS won't show controls
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            print("📱 Setting Now Playing Info:")
            print("   Title: \(trackNames)")
            print("   Rate: \(isPlaying ? 1.0 : 0.0)")
            print("   Duration: 3600.0")
            print("   Active tracks: \(activeTracks.count)")
        } else {
            nowPlayingInfo[MPMediaItemPropertyTitle] = "OpenAmbi"
            nowPlayingInfo[MPMediaItemPropertyArtist] = "No active sounds"
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0.0
        }
        
        // Set the Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Verify it was set
        if MPNowPlayingInfoCenter.default().nowPlayingInfo != nil {
            print("✅ Now Playing Info set successfully")
        } else {
            print("⚠️ Now Playing Info is nil after setting")
        }
    }
    
    func stopAll() {
        isPlaying = false
        for player in audioPlayers.values {
            player.pause()
            player.seek(to: .zero) // Reset to beginning
        }
        
        // Stop all frequency tracks
        for track in tracks where track.isFrequencyTrack && track.isActive {
            frequencyGenerator.stopFrequency(trackId: track.id)
        }
        
        // Update Now Playing info when all tracks stop
        updateNowPlayingInfo()
    }
    
    func reset() {
        stopAll()
        for index in tracks.indices {
            tracks[index].volume = 0.0
            tracks[index].isActive = false
        }
        for player in audioPlayers.values {
            player.volume = 0.0
        }
        
        // All frequency tracks are already stopped by stopAll()
    }
    
    deinit {
        // Clean up observers
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in statusObservers.values {
            observer.invalidate()
        }
        
        // Clean up remote command center handlers
        let commandCenter = MPRemoteCommandCenter.shared()
        if let handler = playHandler {
            commandCenter.playCommand.removeTarget(handler)
        }
        if let handler = pauseHandler {
            commandCenter.pauseCommand.removeTarget(handler)
        }
        if let handler = toggleHandler {
            commandCenter.togglePlayPauseCommand.removeTarget(handler)
        }
        if let handler = stopHandler {
            commandCenter.stopCommand.removeTarget(handler)
        }
        
        // Disable remote control events
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        // Clean up loopers when AudioManager is deallocated
        for looper in playerLooper.values {
            looper.disableLooping()
        }
        playerLooper.removeAll()
        audioPlayers.removeAll()
    }
}

