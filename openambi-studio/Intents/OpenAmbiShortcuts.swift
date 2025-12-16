import Foundation
import Intents
import IntentsUI

/// Siri Shortcuts for OpenAmbi
class OpenAmbiShortcuts {
    
    /// Create a shortcut to play/pause audio
    static func createPlayPauseShortcut() -> INIntent {
        let intent = INPlayMediaIntent()
        // Note: This is a simplified version. Full implementation would require
        // a custom Intent Definition file in Xcode
        return intent
    }
    
    /// Donate play/pause interaction for Siri suggestions
    static func donatePlayPauseInteraction() {
        let intent = INPlayMediaIntent()
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("❌ Failed to donate interaction: \(error.localizedDescription)")
            } else {
                print("✅ Donated play/pause interaction to Siri")
            }
        }
    }
    
    /// Donate stop interaction
    /// Note: Using INPlayMediaIntent for stop as INStopMediaIntent requires custom Intent Definition
    static func donateStopInteraction() {
        // Use INPlayMediaIntent for stop action (standard approach)
        let intent = INPlayMediaIntent()
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("❌ Failed to donate stop interaction: \(error.localizedDescription)")
            } else {
                print("✅ Donated stop interaction to Siri")
            }
        }
    }
}

/// Shortcut actions that can be called from the app
extension OpenAmbiShortcuts {
    
    /// Handle shortcut action
    static func handleShortcut(_ shortcut: String, audioManager: AudioManager) {
        switch shortcut {
        case "play":
            audioManager.play()
            donatePlayPauseInteraction()
        case "pause":
            audioManager.pause()
            donatePlayPauseInteraction()
        case "toggle":
            if audioManager.isPlaying {
                audioManager.pause()
            } else {
                audioManager.play()
            }
            donatePlayPauseInteraction()
        case "stop":
            audioManager.stopAll()
            donateStopInteraction()
        default:
            print("⚠️ Unknown shortcut: \(shortcut)")
        }
    }
}

