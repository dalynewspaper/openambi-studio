import Foundation
import WidgetKit

/// Service to update widget data from the main app
class WidgetUpdateService {
    static let shared = WidgetUpdateService()
    
    private init() {}
    
    /// Update widget with current playback state
    func updateWidget(isPlaying: Bool, activeTrackCount: Int, masterVolume: Double) {
        let defaults = UserDefaults(suiteName: "group.com.openambi.studio")
        defaults?.set(isPlaying, forKey: "widget_isPlaying")
        defaults?.set(activeTrackCount, forKey: "widget_activeTrackCount")
        defaults?.set(masterVolume, forKey: "widget_masterVolume")
        defaults?.synchronize()
        
        // Reload widget timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "OpenAmbiWidget")
    }
}

