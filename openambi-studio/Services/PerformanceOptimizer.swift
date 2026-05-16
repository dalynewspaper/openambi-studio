import Foundation
import AVFoundation

/// Service for optimizing app performance, memory usage, and network efficiency
class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    // Shared URLSession with connection pooling and caching
    private let optimizedURLSession: URLSession

    /// Storage uploads (multi‑MB audio/video) must not share the default
    /// session’s short timeouts — `timeoutIntervalForResource = 30` was
    /// killing ~50MB+ video posts with `NSURLErrorTimedOut` on typical networks.
    private let storageUploadURLSession: URLSession
    
    // Memory-efficient buffer sizes based on track state
    struct BufferConfig {
        let preferredForwardBufferDuration: TimeInterval
        
        static let active = BufferConfig(
            preferredForwardBufferDuration: 0.5  // Minimal buffer for instant playback
        )
        
        static let inactive = BufferConfig(
            preferredForwardBufferDuration: 0.5  // Minimal buffer for inactive tracks
        )
        
        static let cached = BufferConfig(
            preferredForwardBufferDuration: 0.5  // Minimal buffer for cached files (already local)
        )
    }
    
    private init() {
        // Configure URLSession with connection pooling and caching
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB memory cache
            diskCapacity: 50 * 1024 * 1024,      // 50 MB disk cache
            diskPath: "urlcache"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 4  // Connection pooling
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 30.0
        configuration.waitsForConnectivity = false  // Fail fast
        
        // Enable HTTP/2 and connection reuse
        configuration.httpShouldUsePipelining = true
        
        self.optimizedURLSession = URLSession(configuration: configuration)

        let uploadConfiguration = URLSessionConfiguration.default
        uploadConfiguration.urlCache = nil
        uploadConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        uploadConfiguration.httpMaximumConnectionsPerHost = 4
        uploadConfiguration.timeoutIntervalForRequest = 180
        uploadConfiguration.timeoutIntervalForResource = 1800
        uploadConfiguration.waitsForConnectivity = true
        self.storageUploadURLSession = URLSession(configuration: uploadConfiguration)
    }
    
    // MARK: - Public API
    
    /// Get optimized URLSession with connection pooling
    var urlSession: URLSession {
        return optimizedURLSession
    }

    /// Long-timeout session for Supabase Storage `POST` uploads (recordings + video).
    var storageUploadSession: URLSession {
        storageUploadURLSession
    }
    
    /// Get buffer configuration based on track state
    func bufferConfig(for track: AudioTrack, isCached: Bool) -> BufferConfig {
        if isCached {
            return .cached
        }
        return track.isActive ? .active : .inactive
    }
    
    /// Apply optimized buffer settings to AVPlayerItem
    func applyBufferOptimization(to playerItem: AVPlayerItem, config: BufferConfig) {
        playerItem.preferredForwardBufferDuration = config.preferredForwardBufferDuration
    }
    
    /// Optimize memory by releasing unused resources
    func optimizeMemory() {
        // Clear URL cache if memory pressure is high
        URLCache.shared.removeAllCachedResponses()
        
        // Trigger garbage collection hints
        autoreleasepool {
            // Force cleanup of autorelease pools
        }
    }
    
    /// Monitor memory usage
    func getMemoryUsage() -> (used: Int64, available: Int64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = Int64(info.resident_size)
            let total = ProcessInfo.processInfo.physicalMemory
            let available = Int64(total) - used
            return (used, available)
        }
        
        return (0, 0)
    }
}

// MARK: - Lazy Loading Manager

/// Manages lazy loading of audio tracks to reduce memory usage
class LazyTrackLoader {
    static let shared = LazyTrackLoader()
    
    private var loadedTracks: Set<UUID> = []
    private var loadingQueue: [UUID] = []
    private var isLoading = false
    
    private init() {}
    
    /// Check if a track is loaded
    func isTrackLoaded(_ trackId: UUID) -> Bool {
        return loadedTracks.contains(trackId)
    }
    
    /// Mark track as loaded
    func markTrackLoaded(_ trackId: UUID) {
        loadedTracks.insert(trackId)
    }
    
    /// Mark track as unloaded (for memory optimization)
    func markTrackUnloaded(_ trackId: UUID) {
        loadedTracks.remove(trackId)
    }
    
    /// Get tracks that should be preloaded (based on usage patterns)
    func getTracksToPreload(activeTracks: [AudioTrack], allTracks: [AudioTrack]) -> [AudioTrack] {
        // Preload active tracks and tracks in same category
        var toPreload: [AudioTrack] = []
        
        // Always preload active tracks
        toPreload.append(contentsOf: activeTracks)
        
        // Preload tracks in same category as active tracks
        let activeCategories = Set(activeTracks.map { $0.category })
        let sameCategoryTracks = allTracks.filter { track in
            activeCategories.contains(track.category) && 
            !activeTracks.contains(where: { $0.id == track.id }) &&
            !isTrackLoaded(track.id)
        }
        
        // Limit to 3 additional tracks to avoid memory bloat
        toPreload.append(contentsOf: Array(sameCategoryTracks.prefix(3)))
        
        return toPreload
    }
}

