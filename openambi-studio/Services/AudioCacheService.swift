import Foundation
import AVFoundation

/// Service for caching audio files locally to enable instant playback and offline support
class AudioCacheService {
    static let shared = AudioCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB max cache size
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    // Cache metadata - thread-safe access
    private var cacheMetadata: [String: CacheMetadata] = [:]
    private let metadataFile: URL
    private let metadataQueue = DispatchQueue(label: "com.openambi.cacheMetadata", attributes: .concurrent)
    private let saveWorkItemQueue = DispatchQueue(label: "com.openambi.cacheSaveWorkItem", attributes: .concurrent)
    private var saveWorkItem: DispatchWorkItem?
    
    struct CacheMetadata: Codable {
        let url: String
        let localPath: String
        let fileSize: Int64
        let downloadedAt: Date
        var lastAccessed: Date
        var accessCount: Int
        
        init(url: String, localPath: String, fileSize: Int64, downloadedAt: Date = Date(), lastAccessed: Date = Date(), accessCount: Int = 1) {
            self.url = url
            self.localPath = localPath
            self.fileSize = fileSize
            self.downloadedAt = downloadedAt
            self.lastAccessed = lastAccessed
            self.accessCount = accessCount
        }
    }
    
    private init() {
        // Create cache directory in app's caches directory
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("AudioCache", isDirectory: true)
        metadataFile = cacheDirectory.appendingPathComponent("cache_metadata.json")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load existing metadata synchronously during init
        if let data = try? Data(contentsOf: metadataFile),
           let metadata = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) {
            cacheMetadata = metadata
        }
        
        // Clean up old files on init (async, non-blocking)
        Task {
            await cleanupOldFiles()
        }
    }
    
    // MARK: - Public API
    
    /// Get cached file URL if available, otherwise return nil
    func getCachedFileURL(for remoteURL: String) -> URL? {
        // Get metadata snapshot (thread-safe read)
        let metadata = metadataQueue.sync {
            return cacheMetadata[remoteURL]
        }
        
        guard let metadata = metadata else {
            return nil
        }
        
        let localURL = cacheDirectory.appendingPathComponent(metadata.localPath)
        
        // Check if file still exists
        guard fileManager.fileExists(atPath: localURL.path) else {
            // File was deleted, remove from metadata
            metadataQueue.async(flags: .barrier) {
                self.cacheMetadata.removeValue(forKey: remoteURL)
            }
            // Save metadata asynchronously (don't wait)
            saveMetadataAsync()
            return nil
        }
        
        // Update access time (thread-safe write)
        var updatedMetadata = metadata
        updatedMetadata.lastAccessed = Date()
        updatedMetadata.accessCount += 1
        
        metadataQueue.async(flags: .barrier) {
            self.cacheMetadata[remoteURL] = updatedMetadata
        }
        
        // Save metadata asynchronously (don't wait)
        saveMetadataAsync()
        
        return localURL
    }
    
    /// Check if a file is cached
    func isCached(_ remoteURL: String) -> Bool {
        return metadataQueue.sync {
            return cacheMetadata[remoteURL] != nil
        }
    }
    
    /// Download and cache an audio file
    func downloadAndCache(_ remoteURL: String, priority: DownloadPriority = .normal) async throws -> URL {
        // Check if already cached
        if let cachedURL = getCachedFileURL(for: remoteURL) {
            print("✅ File already cached: \(remoteURL)")
            return cachedURL
        }
        
        guard let url = URL(string: remoteURL) else {
            throw CacheError.invalidURL
        }
        
        print("⬇️ Downloading audio file: \(remoteURL)")
        
        // Create download task
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CacheError.downloadFailed
        }
        
        // Get file size
        let fileAttributes = try fileManager.attributesOfItem(atPath: tempURL.path)
        let fileSize = (fileAttributes[.size] as? Int64) ?? 0
        
        // Generate unique filename (use hash of URL to avoid conflicts)
        let filename = remoteURL.hashValue.description + ".m4a"
        let localURL = cacheDirectory.appendingPathComponent(filename)
        
        // Move from temp location to cache
        if fileManager.fileExists(atPath: localURL.path) {
            try? fileManager.removeItem(at: localURL)
        }
        try fileManager.moveItem(at: tempURL, to: localURL)
        
        // Save metadata (thread-safe)
        let metadata = CacheMetadata(
            url: remoteURL,
            localPath: filename,
            fileSize: fileSize
        )
        metadataQueue.async(flags: .barrier) {
            self.cacheMetadata[remoteURL] = metadata
        }
        saveMetadataAsync()
        
        print("✅ Cached audio file: \(remoteURL) -> \(localURL.path)")
        
        // Check cache size and clean up if needed
        await ensureCacheSizeLimit()
        
        return localURL
    }
    
    /// Preload multiple tracks in background
    func preloadTracks(_ urls: [String], priority: DownloadPriority = .low) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        _ = try await self.downloadAndCache(url, priority: priority)
                    } catch {
                        print("⚠️ Failed to preload \(url): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Get cache size in bytes
    func getCacheSize() -> Int64 {
        return metadataQueue.sync {
            return cacheMetadata.values.reduce(0) { $0 + $1.fileSize }
        }
    }
    
    /// Clear all cached files
    func clearCache() throws {
        // Remove all files
        let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for file in files {
            if file.lastPathComponent != "cache_metadata.json" {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // Clear metadata (thread-safe)
        metadataQueue.async(flags: .barrier) {
            self.cacheMetadata.removeAll()
        }
        saveMetadataAsync()
        
        print("🗑️ Cleared audio cache")
    }
    
    /// Remove specific cached file
    func removeCachedFile(_ remoteURL: String) throws {
        let metadata = metadataQueue.sync {
            return cacheMetadata[remoteURL]
        }
        
        guard let metadata = metadata else {
            return
        }
        
        let localURL = cacheDirectory.appendingPathComponent(metadata.localPath)
        try? fileManager.removeItem(at: localURL)
        
        metadataQueue.async(flags: .barrier) {
            self.cacheMetadata.removeValue(forKey: remoteURL)
        }
        saveMetadataAsync()
    }
    
    /// Clear cache for user recordings only (keeps ambient sounds cache)
    func clearUserRecordingsCache() {
        // Get snapshot of metadata (thread-safe)
        let snapshot = metadataQueue.sync {
            return cacheMetadata
        }
        
        // Filter to find user recording URLs (they contain "user-recordings" in the path)
        let userRecordingURLs = snapshot.keys.filter { url in
            url.contains("user-recordings")
        }
        
        print("🗑️ Clearing cache for \(userRecordingURLs.count) user recordings...")
        
        // Remove each user recording cache file
        for url in userRecordingURLs {
            if let metadata = snapshot[url] {
                let localURL = cacheDirectory.appendingPathComponent(metadata.localPath)
                try? fileManager.removeItem(at: localURL)
            }
            
            // Remove from metadata
            metadataQueue.async(flags: .barrier) {
                self.cacheMetadata.removeValue(forKey: url)
            }
        }
        
        saveMetadataAsync()
        print("✅ Cleared user recordings cache")
    }
    
    // MARK: - Private Methods
    
    private func loadMetadata() {
        // This is now handled in init, but keeping for potential future use
        if let data = try? Data(contentsOf: metadataFile),
           let metadata = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) {
            metadataQueue.async(flags: .barrier) {
                self.cacheMetadata = metadata
            }
        } else {
            metadataQueue.async(flags: .barrier) {
                self.cacheMetadata = [:]
            }
        }
    }
    
    private func saveMetadata() {
        saveMetadataAsync()
    }
    
    private func saveMetadataAsync() {
        // Use a serial queue to ensure thread-safe access to saveWorkItem
        saveWorkItemQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Cancel any pending save to debounce
            self.saveWorkItem?.cancel()
            
            // Capture what we need before creating the work item
            let metadataFile = self.metadataFile
            let metadataQueue = self.metadataQueue
            
            // Create new save work item
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // Get a snapshot of metadata for encoding (thread-safe read)
                let snapshot = metadataQueue.sync {
                    return self.cacheMetadata
                }
                
                // Encode and save on background queue
                guard let data = try? JSONEncoder().encode(snapshot) else {
                    print("⚠️ Failed to encode cache metadata")
                    return
                }
                do {
                    try data.write(to: metadataFile)
                } catch {
                    print("⚠️ Failed to save cache metadata: \(error.localizedDescription)")
                }
            }
            
            // Store work item
            self.saveWorkItem = workItem
            
            // Debounce: wait 0.3 seconds before saving (batch multiple updates)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
    
    /// Ensure cache doesn't exceed size limit (LRU eviction)
    private func ensureCacheSizeLimit() async {
        let currentSize = getCacheSize()
        
        if currentSize <= maxCacheSize {
            return
        }
        
        print("🧹 Cache size (\(currentSize / 1024 / 1024) MB) exceeds limit, cleaning up...")
        
        // Get snapshot for sorting (thread-safe)
        let snapshot = metadataQueue.sync {
            return cacheMetadata
        }
        
        // Sort by last accessed time (LRU)
        let sortedEntries = snapshot.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        
        var sizeToRemove = currentSize - maxCacheSize
        for (url, metadata) in sortedEntries {
            if sizeToRemove <= 0 {
                break
            }
            
            do {
                try removeCachedFile(url)
                sizeToRemove -= metadata.fileSize
                print("🗑️ Removed cached file: \(metadata.localPath)")
            } catch {
                print("⚠️ Failed to remove cached file: \(error.localizedDescription)")
            }
        }
        
        print("✅ Cache cleanup complete. New size: \(getCacheSize() / 1024 / 1024) MB")
    }
    
    /// Clean up files older than maxCacheAge
    private func cleanupOldFiles() async {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        
        // Get snapshot for filtering (thread-safe)
        let snapshot = metadataQueue.sync {
            return cacheMetadata
        }
        
        let oldEntries = snapshot.filter { $0.value.downloadedAt < cutoffDate }
        
        for (url, _) in oldEntries {
            try? removeCachedFile(url)
        }
        
        if !oldEntries.isEmpty {
            print("🧹 Cleaned up \(oldEntries.count) old cached files")
        }
    }
    
    enum DownloadPriority {
        case high    // Download immediately
        case normal  // Download in normal queue
        case low     // Download in background
    }
    
    enum CacheError: Error {
        case invalidURL
        case downloadFailed
        case fileSystemError
    }
}

