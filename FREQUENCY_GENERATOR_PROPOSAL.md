# Frequency Generator Implementation Proposal

## Overview

This document outlines the implementation plan for adding a Frequency Generator feature to OpenAmbi Studio. This will allow users to generate pure tones, binaural beats, and isochronic tones associated with different mental states (focus, meditation, sleep, etc.).

---

## Research Summary

### Types of Frequency Generation

#### 1. **Pure Tone Generators**
- Single sine wave at a specific frequency
- Examples: 432 Hz (relaxation), 528 Hz (healing), 741 Hz (problem-solving)
- Simple implementation, low CPU usage

#### 2. **Binaural Beats**
- Two slightly different frequencies played separately to each ear
- Brain perceives a "beat" at the difference frequency
- Requires headphones for best effect
- Example: 200 Hz left ear + 210 Hz right ear = 10 Hz beat (Alpha waves for relaxation)

#### 3. **Isochronic Tones**
- Single tone that pulses on/off at regular intervals
- More effective than binaural beats (works without headphones)
- Example: 200 Hz tone pulsing at 10 Hz creates 10 Hz brainwave entrainment

#### 4. **Brainwave Frequencies**
- **Delta (0.5-4 Hz)**: Deep sleep, healing
- **Theta (4-8 Hz)**: Deep meditation, creativity
- **Alpha (8-14 Hz)**: Relaxation, focus, light meditation
- **Beta (14-30 Hz)**: Active thinking, concentration
- **Gamma (30-100 Hz)**: High-level cognitive processing

#### 5. **Solfeggio Frequencies**
- **396 Hz**: Release fear and guilt
- **417 Hz**: Facilitate change, overcome trauma
- **528 Hz**: DNA repair, transformation, healing
- **639 Hz**: Enhance communication, relationships
- **741 Hz**: Problem-solving, intuition, detoxification
- **852 Hz**: Spiritual awakening, intuition
- **963 Hz**: Awakening intuition, pineal gland activation

---

## Architecture Proposal

### 1. **FrequencyGenerator Service**

Create a new service that uses `AVAudioEngine` (instead of `AVQueuePlayer`) to generate audio in real-time:

```swift
// Services/FrequencyGenerator.swift

import AVFoundation
import Combine

enum FrequencyType {
    case pureTone(frequency: Double)           // Single frequency
    case binauralBeat(baseFreq: Double, beatFreq: Double)  // Two frequencies
    case isochronicTone(frequency: Double, pulseRate: Double)  // Pulsed tone
}

enum FrequencyPreset: String, CaseIterable {
    case focus = "Focus"
    case meditation = "Meditation"
    case sleep = "Sleep"
    case creativity = "Creativity"
    case energy = "Energy"
    
    var frequencyType: FrequencyType {
        switch self {
        case .focus:
            return .isochronicTone(frequency: 200, pulseRate: 14) // Beta waves
        case .meditation:
            return .binauralBeat(baseFreq: 200, beatFreq: 6) // Theta waves
        case .sleep:
            return .binauralBeat(baseFreq: 200, beatFreq: 2) // Delta waves
        case .creativity:
            return .isochronicTone(frequency: 200, pulseRate: 6) // Theta waves
        case .energy:
            return .isochronicTone(frequency: 200, pulseRate: 20) // Beta waves
        }
    }
    
    var description: String {
        switch self {
        case .focus: return "Enhances concentration and mental clarity"
        case .meditation: return "Deep relaxation and mindfulness"
        case .sleep: return "Promotes deep, restful sleep"
        case .creativity: return "Stimulates creative thinking"
        case .energy: return "Boosts alertness and energy"
        }
    }
}

class FrequencyGenerator: ObservableObject {
    private let engine = AVAudioEngine()
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var frequencyTracks: [UUID: FrequencyTrack] = [:]
    private let sampleRate: Double = 44100.0
    private var isEngineRunning = false
    
    struct FrequencyTrack {
        let id: UUID
        let type: FrequencyType
        var volume: Float
        var isActive: Bool
    }
    
    func startFrequency(trackId: UUID, type: FrequencyType, volume: Float) {
        // Create player node
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        
        // Connect to main mixer
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        
        // Generate and schedule audio buffer
        let buffer = generateBuffer(for: type)
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        
        playerNodes[trackId] = playerNode
        frequencyTracks[trackId] = FrequencyTrack(id: trackId, type: type, volume: volume, isActive: true)
        
        // Start engine if not running
        if !isEngineRunning {
            do {
                try engine.start()
                isEngineRunning = true
            } catch {
                print("❌ Failed to start audio engine: \(error)")
            }
        }
        
        // Set volume and play
        playerNode.volume = volume
        playerNode.play()
    }
    
    func stopFrequency(trackId: UUID) {
        guard let playerNode = playerNodes[trackId] else { return }
        playerNode.stop()
        playerNode.reset()
        engine.detach(playerNode)
        playerNodes.removeValue(forKey: trackId)
        frequencyTracks.removeValue(forKey: trackId)
        
        // Stop engine if no active tracks
        if playerNodes.isEmpty && isEngineRunning {
            engine.stop()
            isEngineRunning = false
        }
    }
    
    func updateVolume(trackId: UUID, volume: Float) {
        guard let playerNode = playerNodes[trackId] else { return }
        playerNode.volume = volume
        if var track = frequencyTracks[trackId] {
            track.volume = volume
            frequencyTracks[trackId] = track
        }
    }
    
    private func generateBuffer(for type: FrequencyType) -> AVAudioPCMBuffer {
        let duration: Double = 1.0 // 1 second buffer, loops seamlessly
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }
        
        switch type {
        case .pureTone(let frequency):
            // Same frequency to both channels
            generateSineWave(channel: leftChannel, frequency: frequency, frameCount: frameCount)
            generateSineWave(channel: rightChannel, frequency: frequency, frameCount: frameCount)
            
        case .binauralBeat(let baseFreq, let beatFreq):
            // Different frequencies to each ear
            let leftFreq = baseFreq
            let rightFreq = baseFreq + beatFreq
            generateSineWave(channel: leftChannel, frequency: leftFreq, frameCount: frameCount)
            generateSineWave(channel: rightChannel, frequency: rightFreq, frameCount: frameCount)
            
        case .isochronicTone(let frequency, let pulseRate):
            // Pulsed tone to both channels
            generateIsochronicTone(
                leftChannel: leftChannel,
                rightChannel: rightChannel,
                frequency: frequency,
                pulseRate: pulseRate,
                frameCount: frameCount
            )
        }
        
        return buffer
    }
    
    private func generateSineWave(channel: UnsafeMutablePointer<Float>, frequency: Double, frameCount: AVAudioFrameCount) {
        for i in 0..<Int(frameCount) {
            let sampleTime = Double(i) / sampleRate
            channel[i] = Float(sin(2.0 * .pi * frequency * sampleTime)) * 0.3 // 30% amplitude
        }
    }
    
    private func generateIsochronicTone(
        leftChannel: UnsafeMutablePointer<Float>,
        rightChannel: UnsafeMutablePointer<Float>,
        frequency: Double,
        pulseRate: Double,
        frameCount: AVAudioFrameCount
    ) {
        let pulsePeriod = sampleRate / pulseRate // Frames per pulse cycle
        let pulseDuration = pulsePeriod / 2 // 50% duty cycle (on/off)
        
        for i in 0..<Int(frameCount) {
            let sampleTime = Double(i) / sampleRate
            let pulsePhase = Double(i).truncatingRemainder(dividingBy: pulsePeriod)
            let isPulseOn = pulsePhase < pulseDuration
            
            let amplitude: Float = isPulseOn ? 0.3 : 0.0
            let sample = Float(sin(2.0 * .pi * frequency * sampleTime)) * amplitude
            
            leftChannel[i] = sample
            rightChannel[i] = sample
        }
    }
}
```

### 2. **Extend AudioTrack Model**

Add support for frequency-based tracks:

```swift
// Models/AudioTrack.swift (additions)

enum TrackType: String, Codable {
    case audioFile = "audio_file"      // Existing: plays from URL
    case frequency = "frequency"       // New: generates frequency
}

struct AudioTrack: Identifiable, Codable, Equatable {
    // ... existing properties ...
    let trackType: TrackType
    var frequencyPreset: FrequencyPreset?  // Optional: for frequency tracks
    
    // Computed property to check if this is a frequency track
    var isFrequencyTrack: Bool {
        return trackType == .frequency
    }
}
```

### 3. **Integrate with AudioManager**

Modify `AudioManager` to handle both file-based and frequency-based tracks:

```swift
// Services/AudioManager.swift (additions)

class AudioManager: ObservableObject {
    // ... existing properties ...
    private let frequencyGenerator = FrequencyGenerator()
    
    func toggleTrack(_ trackId: UUID, isActive: Bool) {
        guard let track = tracks.first(where: { $0.id == trackId }) else { return }
        
        if track.isFrequencyTrack {
            // Handle frequency track
            if isActive {
                guard let preset = track.frequencyPreset else { return }
                let volume = Float(track.volume * masterVolume)
                frequencyGenerator.startFrequency(
                    trackId: trackId,
                    type: preset.frequencyType,
                    volume: volume
                )
            } else {
                frequencyGenerator.stopFrequency(trackId: trackId)
            }
        } else {
            // Existing file-based track handling
            // ... existing code ...
        }
    }
    
    func updateTrackVolume(_ trackId: UUID, volume: Double) {
        guard let track = tracks.first(where: { $0.id == trackId }) else { return }
        
        if track.isFrequencyTrack {
            let floatVolume = Float(volume * masterVolume)
            frequencyGenerator.updateVolume(trackId: trackId, volume: floatVolume)
        } else {
            // Existing file-based volume update
            // ... existing code ...
        }
    }
}
```

### 4. **Create Frequency Track Presets**

Add frequency tracks to the available sound library:

```swift
// Services/FrequencyPresetService.swift

class FrequencyPresetService {
    static func createFrequencyTracks() -> [AudioTrack] {
        return FrequencyPreset.allCases.map { preset in
            AudioTrack(
                name: preset.rawValue,
                category: "frequency",
                icon: iconForPreset(preset),
                description: preset.description,
                audioUrl: "frequency://\(preset.rawValue)", // Special URL scheme
                trackType: .frequency,
                frequencyPreset: preset,
                isActive: false,
                volume: 0.0
            )
        }
    }
    
    private static func iconForPreset(_ preset: FrequencyPreset) -> String {
        switch preset {
        case .focus: return "brain.head.profile"
        case .meditation: return "leaf.fill"
        case .sleep: return "moon.zzz.fill"
        case .creativity: return "paintbrush.fill"
        case .energy: return "bolt.fill"
        }
    }
}
```

---

## Implementation Steps

### Phase 1: Core Frequency Generator (Week 1)
1. ✅ Create `FrequencyGenerator` service
2. ✅ Implement pure tone generation
3. ✅ Implement binaural beats
4. ✅ Implement isochronic tones
5. ✅ Test with headphones and speakers

### Phase 2: Integration (Week 1-2)
1. ✅ Extend `AudioTrack` model with `TrackType`
2. ✅ Integrate `FrequencyGenerator` into `AudioManager`
3. ✅ Update `toggleTrack` and `updateTrackVolume` methods
4. ✅ Ensure frequency tracks can mix with file-based tracks

### Phase 3: UI Integration (Week 2)
1. ✅ Create frequency preset tracks
2. ✅ Add frequency tracks to sound library
3. ✅ Update UI to show frequency tracks (same grid system)
4. ✅ Add visual indicator for frequency tracks (different icon/style)

### Phase 4: Advanced Features (Week 3)
1. ✅ Add custom frequency controls (user-adjustable frequency)
2. ✅ Add frequency visualization (waveform display)
3. ✅ Add preset customization
4. ✅ Add frequency mixing (multiple frequencies simultaneously)

---

## UI Considerations

### Visual Design
- **Icon**: Use SF Symbols like `waveform`, `brain.head.profile`, or custom frequency icon
- **Color**: Distinct color scheme (e.g., purple/violet) to differentiate from nature/indoor sounds
- **Indicator**: Subtle animation showing frequency waveform or pulse

### User Experience
- **Preset Selection**: Show preset name and description when selected
- **Headphone Warning**: Optional alert for binaural beats (works best with headphones)
- **Volume Control**: Same volume slider system as other tracks
- **Mixing**: Frequency tracks can be mixed with ambient sounds

### Settings
- **Custom Frequencies**: Allow users to create custom frequency presets
- **Frequency Range**: Slider to adjust base frequency (e.g., 100-500 Hz)
- **Beat Frequency**: Slider for binaural beats (e.g., 1-30 Hz)
- **Pulse Rate**: Slider for isochronic tones (e.g., 1-30 Hz)

---

## Technical Considerations

### Performance
- **CPU Usage**: Frequency generation is CPU-efficient (sine wave calculation)
- **Memory**: Minimal memory usage (1-second buffers that loop)
- **Battery**: Lower battery impact than streaming audio files

### Audio Mixing
- **AVAudioEngine**: Can mix with `AVQueuePlayer` through audio session
- **Volume Control**: Independent volume per frequency track
- **Master Volume**: Applies to frequency tracks same as file tracks

### Compatibility
- **Headphones**: Binaural beats require headphones for best effect
- **Speakers**: Isochronic tones work well with speakers
- **AirPods**: Works with wireless headphones

---

## Recommended Presets

### Focus (Beta Waves - 14-20 Hz)
- **Type**: Isochronic tone
- **Base Frequency**: 200 Hz
- **Pulse Rate**: 16 Hz
- **Use Case**: Work, study, concentration

### Meditation (Theta Waves - 4-8 Hz)
- **Type**: Binaural beat
- **Base Frequency**: 200 Hz
- **Beat Frequency**: 6 Hz
- **Use Case**: Deep meditation, mindfulness

### Sleep (Delta Waves - 0.5-4 Hz)
- **Type**: Binaural beat
- **Base Frequency**: 200 Hz
- **Beat Frequency**: 2 Hz
- **Use Case**: Falling asleep, deep sleep

### Creativity (Theta Waves - 4-8 Hz)
- **Type**: Isochronic tone
- **Base Frequency**: 200 Hz
- **Pulse Rate**: 6 Hz
- **Use Case**: Creative work, brainstorming

### Energy (Beta Waves - 14-30 Hz)
- **Type**: Isochronic tone
- **Base Frequency**: 200 Hz
- **Pulse Rate**: 20 Hz
- **Use Case**: Morning routine, exercise, alertness

---

## Future Enhancements

1. **Solfeggio Frequencies**: Add preset for each Solfeggio frequency
2. **Custom Waveforms**: Allow users to choose sine, square, triangle waves
3. **Frequency Sweeps**: Gradually change frequency over time
4. **Pink/White Noise**: Add noise generators for masking
5. **Frequency Analysis**: Show real-time frequency spectrum
6. **Export**: Allow users to export generated frequencies as audio files

---

## Testing Checklist

- [ ] Pure tone generation works correctly
- [ ] Binaural beats work with headphones
- [ ] Isochronic tones work with speakers
- [ ] Frequency tracks can be mixed with file tracks
- [ ] Volume control works for frequency tracks
- [ ] Master volume affects frequency tracks
- [ ] Multiple frequency tracks can play simultaneously
- [ ] App handles audio session interruptions
- [ ] Background playback works
- [ ] Lock screen controls work
- [ ] Battery usage is acceptable
- [ ] No audio glitches or clicks

---

## Conclusion

This implementation will add a powerful frequency generation feature to OpenAmbi Studio, allowing users to create custom soundscapes that combine ambient sounds with brainwave entrainment frequencies. The architecture is designed to integrate seamlessly with the existing audio system while maintaining performance and user experience.
