import Foundation
import SwiftUI

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Playback Settings
    @AppStorage("fadeInDuration") var fadeInDuration: Double = 1.0
    @AppStorage("fadeOutOnExit") var fadeOutOnExit: Bool = true
    @AppStorage("fadeOutDuration") var fadeOutDuration: Double = 3.0
    @AppStorage("backgroundPlayback") var backgroundPlayback: Bool = true
    @AppStorage("resumeLastMix") var resumeLastMix: Bool = true
    
    // Audio Quality Settings
    @AppStorage("audioQuality") var audioQuality: AudioQuality = .normal
    @AppStorage("downloadQuality") var downloadQuality: DownloadQuality = .wifiOnly
    
    // Appearance Settings
    @AppStorage("theme") var theme: ThemePreference = .system
    @AppStorage("liquidGlassEffects") var liquidGlassEffects: Bool = true
    @AppStorage("reduceMotion") var reduceMotion: Bool = false
    @AppStorage("backgroundBlurStrength") var backgroundBlurStrength: BlurStrength = .medium
    
    // Notifications Settings
    @AppStorage("notificationsNewScenes") var notificationsNewScenes: Bool = true
    @AppStorage("notificationsDailyMix") var notificationsDailyMix: Bool = true
    @AppStorage("notificationsRelaxation") var notificationsRelaxation: Bool = false
    
    // Data & Sync Settings
    @AppStorage("iCloudSync") var iCloudSync: Bool = true
    
    // Privacy Settings
    @AppStorage("analyticsEnabled") var analyticsEnabled: Bool = true
    
    // Pro/Premium Settings
    @AppStorage("defaultStartAmbience") var defaultStartAmbience: String = "Rain"
    @AppStorage("autoMixNormalisation") var autoMixNormalisation: Bool = true
    @AppStorage("hapticsOnTap") var hapticsOnTap: Bool = true
    @AppStorage("sleepTimerDefault") var sleepTimerDefault: Int = 60 // minutes
    @AppStorage("spatialAudioMode") var spatialAudioMode: Bool = false
    
    private init() {}
    
    func clearCachedAudio() {
        // Clear audio cache
        do {
            try AudioCacheService.shared.clearCache()
        } catch {
            print("⚠️ Failed to clear cache: \(error)")
        }
    }
}

// MARK: - Enums
enum AudioQuality: String, CaseIterable {
    case normal = "Normal"
    case highFidelity = "High Fidelity"
    case lossless = "Lossless"
}

enum DownloadQuality: String, CaseIterable {
    case wifiOnly = "Wi‑Fi Only"
    case wifiAndCellular = "Wi‑Fi + Cellular"
}

enum ThemePreference: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

enum BlurStrength: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum FadeDuration: Double, CaseIterable {
    case instant = 0
    case oneSecond = 1
    case threeSeconds = 3
    case fiveSeconds = 5
    
    var displayName: String {
        switch self {
        case .instant: return "0s"
        case .oneSecond: return "1s"
        case .threeSeconds: return "3s"
        case .fiveSeconds: return "5s"
        }
    }
}


