import Foundation

enum TrackType: String, Codable {
    case audioFile = "audio_file"      // Existing: plays from URL
    case frequency = "frequency"       // New: generates frequency
}

enum FrequencyType: Codable, Equatable {
    case pureTone(frequency: Double)           // Single frequency
    case binauralBeat(baseFreq: Double, beatFreq: Double)  // Two frequencies
    case isochronicTone(frequency: Double, pulseRate: Double)  // Pulsed tone
}

enum FrequencyPreset: String, CaseIterable, Codable {
    case sleep = "Sleep"
    case creativity = "Creativity"
    
    var frequencyType: FrequencyType {
        switch self {
        case .sleep:
            return .binauralBeat(baseFreq: 200, beatFreq: 2) // Delta waves
        case .creativity:
            return .isochronicTone(frequency: 200, pulseRate: 6) // Theta waves
        }
    }
    
    var description: String {
        switch self {
        case .sleep: return "Promotes deep, restful sleep"
        case .creativity: return "Stimulates creative thinking"
        }
    }
    
    var icon: String {
        switch self {
        case .sleep: return "moon.zzz.fill"
        case .creativity: return "paintbrush.fill"
        }
    }
}

struct AudioTrack: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let category: String // "nature", "indoor", "frequency", or user-defined
    let icon: String
    let description: String?
    let audioUrl: String
    var videoUrl: String? = nil
    
    // Advanced audio rendering
    var useAdvancedRendering: Bool = false
    var spatialX: Float = 0       // -1 (left) to 1 (right)
    var spatialY: Float = 0       // -1 (back) to 1 (front)
    var reverbMix: Float = 0      // 0 (dry) to 1 (full wet)
    var eqLowGain: Float = 0      // dB
    var eqMidGain: Float = 0      // dB
    var eqHighGain: Float = 0     // dB
    
    let trackType: TrackType
    var frequencyPreset: FrequencyPreset?  // Optional: for frequency tracks
    var isActive: Bool
    var volume: Double // 0.0 to 1.0
    
    // User recording properties
    var isUserRecording: Bool = false
    var userId: UUID? = nil
    var recordedAt: Date? = nil
    var duration: TimeInterval? = nil // Duration in seconds for user recordings
    var locationName: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var imageUrl: String? = nil
    var playCount: Int = 0
    var lastPlayedAt: Date? = nil
    
    // Computed property to check if this is a frequency track
    var isFrequencyTrack: Bool {
        return trackType == .frequency
    }
    
    // Computed property to check if this is a user recording
    var isUserRecorded: Bool {
        return isUserRecording
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        icon: String,
        description: String? = nil,
        audioUrl: String,
        videoUrl: String? = nil,
        trackType: TrackType = .audioFile,
        frequencyPreset: FrequencyPreset? = nil,
        isActive: Bool = false,
        volume: Double = 0.0,
        isUserRecording: Bool = false,
        userId: UUID? = nil,
        recordedAt: Date? = nil,
        duration: TimeInterval? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        imageUrl: String? = nil,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.description = description
        self.audioUrl = audioUrl
        self.videoUrl = videoUrl
        self.trackType = trackType
        self.frequencyPreset = frequencyPreset
        self.isActive = isActive
        self.volume = volume
        self.isUserRecording = isUserRecording
        self.userId = userId
        self.recordedAt = recordedAt
        self.duration = duration
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.imageUrl = imageUrl
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
}

struct Preset: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
    let description: String
    let trackConfigurations: [String: Double] // track name -> volume
    
    init(id: UUID = UUID(), name: String, icon: String, description: String, trackConfigurations: [String: Double]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.trackConfigurations = trackConfigurations
    }
}


