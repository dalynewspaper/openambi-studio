import Foundation
import AVFoundation

// MARK: - Local Recording Storage
/// Manages local storage of recordings when cloud upload fails
class LocalRecordingStorage {
    static let shared = LocalRecordingStorage()
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let recordingsKey = "localRecordings"
    
    // Directory for storing local recordings
    private var localRecordingsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("LocalRecordings", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: recordingsDir.path) {
            try? fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }
        
        return recordingsDir
    }
    
    private init() {}
    
    // MARK: - Save Recording Locally
    /// Saves a recording locally with metadata
    func saveRecording(
        fileURL: URL,
        id: UUID,
        title: String,
        category: String,
        description: String?,
        icon: String,
        duration: TimeInterval,
        fileSize: Int64,
        videoURL: URL? = nil,
        locationName: String?,
        latitude: Double?,
        longitude: Double?,
        recordedAt: Date = Date()
    ) throws {
        // Copy file to local storage directory
        let localFileURL = localRecordingsDirectory.appendingPathComponent("\(id.uuidString).m4a")
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: localFileURL.path) {
            try? fileManager.removeItem(at: localFileURL)
        }
        
        // Copy the file
        try fileManager.copyItem(at: fileURL, to: localFileURL)
        print("💾 Saved recording locally: \(localFileURL.path)")
        
        // Create metadata
        let videoFilePath = storeVideoIfNeeded(videoURL, id: id)

        let metadata = LocalRecordingMetadata(
            id: id,
            title: title,
            category: category,
            description: description,
            icon: icon,
            duration: duration,
            fileSize: fileSize,
            videoFileURL: videoFilePath,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            recordedAt: recordedAt,
            localFileURL: localFileURL.path,
            synced: false
        )
        
        // Save metadata
        var recordings = loadLocalRecordings()
        recordings.append(metadata)
        saveLocalRecordings(recordings)
        
        print("✅ Saved recording metadata locally: \(title) (ID: \(id.uuidString.prefix(8)))")
    }
    
    // MARK: - Load Local Recordings
    /// Loads all locally stored recordings
    func loadLocalRecordings() -> [LocalRecordingMetadata] {
        guard let data = userDefaults.data(forKey: recordingsKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([LocalRecordingMetadata].self, from: data)
        } catch {
            print("❌ Failed to decode local recordings: \(error)")
            return []
        }
    }
    
    // MARK: - Get Recording File URL
    /// Gets the local file URL for a recording
    func getRecordingFileURL(id: UUID) -> URL? {
        let recordings = loadLocalRecordings()
        guard let recording = recordings.first(where: { $0.id == id }) else {
            return nil
        }
        
        let fileURL = URL(fileURLWithPath: recording.localFileURL)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ Local recording file not found: \(fileURL.path)")
            return nil
        }
        
        return fileURL
    }
    
    // MARK: - Mark as Synced
    /// Marks a recording as synced to cloud
    func markAsSynced(id: UUID) {
        var recordings = loadLocalRecordings()
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            recordings[index].synced = true
            saveLocalRecordings(recordings)
            print("✅ Marked recording as synced: \(id.uuidString.prefix(8))")
        }
    }
    
    // MARK: - Delete Local Recording
    /// Deletes a local recording and its file
    func deleteRecording(id: UUID) throws {
        var recordings = loadLocalRecordings()
        guard let index = recordings.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        let recording = recordings[index]
        
        // Delete file
        let fileURL = URL(fileURLWithPath: recording.localFileURL)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            print("🗑️ Deleted local recording file: \(fileURL.path)")
        }
        
        // Remove from metadata
        recordings.remove(at: index)
        saveLocalRecordings(recordings)
        
        print("✅ Deleted local recording: \(id.uuidString.prefix(8))")
    }
    
    // MARK: - Get Unsynced Recordings
    /// Gets all recordings that haven't been synced to cloud
    func getUnsyncedRecordings() -> [LocalRecordingMetadata] {
        return loadLocalRecordings().filter { !$0.synced }
    }
    
    // MARK: - Convert to AudioTrack
    /// Converts a local recording to an AudioTrack
    func toAudioTrack(_ metadata: LocalRecordingMetadata) -> AudioTrack? {
        guard let fileURL = getRecordingFileURL(id: metadata.id) else {
            return nil
        }

        let videoUrlString: String?
        if let videoFileURL = metadata.videoFileURL {
            videoUrlString = URL(fileURLWithPath: videoFileURL).absoluteString
        } else {
            videoUrlString = nil
        }
        
        return AudioTrack(
            id: metadata.id,
            name: metadata.title,
            category: metadata.category,
            icon: metadata.icon,
            description: metadata.description,
            audioUrl: fileURL.absoluteString, // Local file URL
            videoUrl: videoUrlString,
            trackType: .audioFile,
            isActive: false,
            volume: 0.0,
            isUserRecording: true,
            userId: nil, // Will be set when synced
            recordedAt: metadata.recordedAt,
            duration: metadata.duration,
            locationName: metadata.locationName,
            latitude: metadata.latitude,
            longitude: metadata.longitude
        )
    }
    
    // MARK: - Private Helpers
    private func saveLocalRecordings(_ recordings: [LocalRecordingMetadata]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recordings)
            userDefaults.set(data, forKey: recordingsKey)
        } catch {
            print("❌ Failed to encode local recordings: \(error)")
        }
    }

    private func storeVideoIfNeeded(_ videoURL: URL?, id: UUID) -> String? {
        guard let videoURL else { return nil }

        do {
            let savedURL = try VideoAssetStore.shared.saveVideoAsset(sourceURL: videoURL, id: id)
            print("🎬 Saved video locally: \(savedURL.path)")
            return savedURL.path
        } catch {
            print("⚠️ Failed to save video locally: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Local Recording Metadata
struct LocalRecordingMetadata: Codable {
    let id: UUID
    let title: String
    let category: String
    let description: String?
    let icon: String
    let duration: TimeInterval
    let fileSize: Int64
    let videoFileURL: String?
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let recordedAt: Date
    let localFileURL: String
    var synced: Bool
}

