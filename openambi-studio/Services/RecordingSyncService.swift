import Foundation
import Network

// MARK: - Recording Sync Service
/// Syncs locally stored recordings to cloud when online
class RecordingSyncService {
    static let shared = RecordingSyncService()
    
    private let localStorage = LocalRecordingStorage.shared
    private let supabaseService = SupabaseService()
    private let networkMonitor = NWPathMonitor()
    private var isMonitoring = false
    private var syncTask: Task<Void, Never>?
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        let queue = DispatchQueue(label: "com.openambi.networkmonitor")
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("🌐 Network available - checking for unsynced recordings")
                Task { @MainActor in
                    await self?.syncUnsyncedRecordings()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - Sync Unsynced Recordings
    /// Attempts to sync all unsynced local recordings to cloud
    @MainActor
    func syncUnsyncedRecordings() async {
        // Cancel any existing sync task
        syncTask?.cancel()
        
        syncTask = Task {
            let unsynced = localStorage.getUnsyncedRecordings()
            
            guard !unsynced.isEmpty else {
                print("✅ No unsynced recordings to sync")
                return
            }
            
            print("🔄 Syncing \(unsynced.count) unsynced recording(s)...")
            
            // Get auth manager (we'll need to pass this in or access it)
            // For now, we'll check if user is authenticated via a notification
            // In a real implementation, you'd inject AuthManager
            
            // Post notification to trigger sync from views that have auth context
            NotificationCenter.default.post(
                name: NSNotification.Name("SyncLocalRecordings"),
                object: nil
            )
        }
    }
    
    // MARK: - Sync Single Recording
    /// Syncs a single local recording to cloud
    func syncRecording(
        metadata: LocalRecordingMetadata,
        accessToken: String,
        userId: UUID
    ) async throws -> AudioTrack {
        guard let fileURL = localStorage.getRecordingFileURL(id: metadata.id) else {
            throw NSError(domain: "Sync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Local file not found"])
        }
        
        print("🔄 Syncing recording: \(metadata.title) (ID: \(metadata.id.uuidString.prefix(8)))")

        let videoFileURL: URL? = metadata.videoFileURL.flatMap { path in
            let u = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }

        // Upload to cloud (audio + optional local video file)
        let track = try await supabaseService.uploadRecording(
            recordingId: metadata.id,
            fileURL: fileURL,
            accessToken: accessToken,
            userId: userId,
            title: metadata.title,
            category: metadata.category,
            description: metadata.description,
            icon: metadata.icon,
            duration: metadata.duration,
            fileSize: metadata.fileSize,
            locationName: metadata.locationName,
            latitude: metadata.latitude,
            longitude: metadata.longitude,
            videoFileURL: videoFileURL
        )
        
        // Mark as synced
        localStorage.markAsSynced(id: metadata.id)
        
        // Delete local file (now that it's in cloud)
        try? localStorage.deleteRecording(id: metadata.id)
        
        print("✅ Successfully synced recording: \(metadata.title)")
        
        return track
    }
    
    // MARK: - Manual Sync
    /// Manually triggers sync of all unsynced recordings
    @MainActor
    func manualSync(authManager: AuthManager) async {
        guard let user = authManager.currentUser else {
            print("⚠️ Cannot sync: user not authenticated")
            return
        }
        
        guard let accessToken = await authManager.getAccessToken() else {
            print("⚠️ Cannot sync: no access token")
            return
        }
        
        let unsynced = localStorage.getUnsyncedRecordings()
        guard !unsynced.isEmpty else {
            print("✅ No unsynced recordings")
            return
        }
        
        print("🔄 Manually syncing \(unsynced.count) recording(s)...")
        
        var syncedCount = 0
        var failedCount = 0
        
        for metadata in unsynced {
            do {
                let track = try await syncRecording(
                    metadata: metadata,
                    accessToken: accessToken,
                    userId: user.id
                )
                syncedCount += 1
                print("✅ Synced: \(track.name)")
                
                // Post notification for UI update
                NotificationCenter.default.post(
                    name: NSNotification.Name("RecordingSynced"),
                    object: nil,
                    userInfo: ["track": track]
                )
            } catch {
                failedCount += 1
                print("❌ Failed to sync \(metadata.title): \(error.localizedDescription)")
            }
        }
        
        print("✅ Sync complete: \(syncedCount) succeeded, \(failedCount) failed")
    }
}

