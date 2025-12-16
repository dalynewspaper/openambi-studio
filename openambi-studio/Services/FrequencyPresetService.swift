import Foundation

class FrequencyPresetService {
    static let shared = FrequencyPresetService()
    
    private init() {}
    
    func createFrequencyTracks() -> [AudioTrack] {
        return FrequencyPreset.allCases.map { preset in
            AudioTrack(
                name: preset.rawValue,
                category: "frequency",
                icon: preset.icon,
                description: preset.description,
                audioUrl: "frequency://\(preset.rawValue)", // Special URL scheme for frequency tracks
                trackType: .frequency,
                frequencyPreset: preset,
                isActive: false,
                volume: 0.0
            )
        }
    }
}
