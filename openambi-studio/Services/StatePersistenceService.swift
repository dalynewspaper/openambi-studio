import Foundation

/// Service for persisting and retrieving the user's last active mix state
class StatePersistenceService {
    static let shared = StatePersistenceService()
    
    private let userDefaults = UserDefaults.standard
    private let lastActiveMixKey = "lastActiveMix"
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    private let appLaunchCountKey = "appLaunchCount"
    private let lastLaunchDateKey = "lastLaunchDate"
    
    private init() {}
    
    /// Save the current active mix state
    func saveLastActiveMix(_ tracks: [AudioTrack]) {
        // Only save tracks that are active and have volume > 0
        let activeTracks = tracks.filter { $0.isActive && $0.volume > 0 }
        
        guard !activeTracks.isEmpty else {
            // If no active tracks, don't save (will default to Rain on next launch)
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(activeTracks)
            userDefaults.set(data, forKey: lastActiveMixKey)
            print("💾 Saved last active mix with \(activeTracks.count) tracks")
        } catch {
            print("❌ Failed to save last active mix: \(error)")
        }
    }
    
    /// Load the last active mix state
    func loadLastActiveMix() -> [AudioTrack]? {
        guard let data = userDefaults.data(forKey: lastActiveMixKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let tracks = try decoder.decode([AudioTrack].self, from: data)
            print("📂 Loaded last active mix with \(tracks.count) tracks")
            return tracks
        } catch {
            print("❌ Failed to load last active mix: \(error)")
            return nil
        }
    }
    
    /// Check if this is the first launch ever
    func isFirstLaunch() -> Bool {
        return !userDefaults.bool(forKey: hasLaunchedBeforeKey)
    }
    
    /// Mark that the app has been launched
    func markLaunched() {
        userDefaults.set(true, forKey: hasLaunchedBeforeKey)
        
        // Track launch count and date for skip logic
        let currentCount = userDefaults.integer(forKey: appLaunchCountKey)
        userDefaults.set(currentCount + 1, forKey: appLaunchCountKey)
        userDefaults.set(Date(), forKey: lastLaunchDateKey)
    }
    
    /// Check if cinematic should be auto-skipped (user opened app >3x in <24 hours)
    func shouldAutoSkipCinematic() -> Bool {
        let launchCount = userDefaults.integer(forKey: appLaunchCountKey)
        guard let lastLaunchDate = userDefaults.object(forKey: lastLaunchDateKey) as? Date else {
            return false
        }
        
        let hoursSinceLastLaunch = Date().timeIntervalSince(lastLaunchDate) / 3600
        
        // If opened >3x and last launch was <24 hours ago, allow skip
        return launchCount > 3 && hoursSinceLastLaunch < 24
    }
    
    /// Clear saved mix (for testing)
    func clearLastActiveMix() {
        userDefaults.removeObject(forKey: lastActiveMixKey)
    }
    
    /// Remove specific tracks from saved mix (e.g., when recordings are deleted)
    func removeTracksFromSavedMix(_ trackIds: Set<UUID>) {
        guard let data = userDefaults.data(forKey: lastActiveMixKey),
              var savedTracks = try? JSONDecoder().decode([AudioTrack].self, from: data) else {
            return // No saved mix or can't decode
        }
        
        let originalCount = savedTracks.count
        savedTracks.removeAll { trackIds.contains($0.id) }
        
        if savedTracks.count != originalCount {
            // Some tracks were removed, save the updated mix
            if savedTracks.isEmpty {
                // If no tracks left, clear the saved mix entirely
                clearLastActiveMix()
                print("🗑️ Cleared saved mix (all tracks were deleted)")
            } else {
                // Save the updated mix without deleted tracks
                if let updatedData = try? JSONEncoder().encode(savedTracks) {
                    userDefaults.set(updatedData, forKey: lastActiveMixKey)
                    print("🗑️ Removed \(originalCount - savedTracks.count) deleted recording(s) from saved mix")
                }
            }
        }
    }
    
    /// Filter saved mix to only include tracks that exist in the provided list
    func filterSavedMixToValidTracks(_ validTrackIds: Set<UUID>) {
        guard let data = userDefaults.data(forKey: lastActiveMixKey),
              var savedTracks = try? JSONDecoder().decode([AudioTrack].self, from: data) else {
            return // No saved mix or can't decode
        }
        
        let originalCount = savedTracks.count
        savedTracks.removeAll { !validTrackIds.contains($0.id) }
        
        if savedTracks.count != originalCount {
            // Some tracks were removed, save the updated mix
            if savedTracks.isEmpty {
                clearLastActiveMix()
                print("🗑️ Cleared saved mix (no valid tracks remaining)")
            } else {
                if let updatedData = try? JSONEncoder().encode(savedTracks) {
                    userDefaults.set(updatedData, forKey: lastActiveMixKey)
                    print("🗑️ Filtered saved mix: removed \(originalCount - savedTracks.count) invalid tracks")
                }
            }
        }
    }
}

