import SwiftUI

/// Derives a stable color palette for any `AudioTrack`.
///
/// User recordings don't have album art, but they deserve a unique color
/// identity in the Field library. We compute the palette deterministically
/// so the same recording always looks the same on every device and every
/// launch — no flicker, no async work, no surprise.
///
/// Resolution order:
/// 1. If the recording's name contains a keyword that maps to a known
///    `SoundColor` preset (rain, ocean, fireplace, …), use that preset.
///    This keeps user recordings named after natural elements in visual
///    coherence with the Studio's built-in scene.
/// 2. Otherwise derive a (primary, secondary) HSB pair from the track's
///    UUID. The hue distribution is unbounded but the saturation and
///    brightness are constrained so every card reads as a member of the
///    same family — coherent, never garish.
enum RecordingPalette {

    /// Two-stop linear gradient suitable for circular thumbnails.
    static func gradient(for track: AudioTrack) -> LinearGradient {
        let (top, bottom) = stops(for: track)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The brighter of the two stops — useful for shadows, rings, and the
    /// `dominantSoundColor` environment when this card is selected.
    static func dominantColor(for track: AudioTrack) -> Color {
        stops(for: track).0
    }

    /// (primary, secondary) color stops.
    static func stops(for track: AudioTrack) -> (Color, Color) {
        if let preset = keywordPreset(for: track.name) {
            return preset
        }
        return uuidPalette(track.id)
    }

    // MARK: - Internals

    private static func keywordPreset(for name: String) -> (Color, Color)? {
        let n = name.lowercased()
        if n.contains("rain")            { return (SoundColor.rain, SoundColor.rainDark) }
        if n.contains("ocean") || n.contains("wave") { return (SoundColor.ocean, SoundColor.oceanDark) }
        if n.contains("bird")            { return (SoundColor.birds, SoundColor.birdsDark) }
        if n.contains("wind")            { return (SoundColor.wind, SoundColor.windDark) }
        if n.contains("thunder")         { return (SoundColor.thunder, SoundColor.thunderDark) }
        if n.contains("river")           { return (SoundColor.river, SoundColor.riverDark) }
        if n.contains("fire")            { return (SoundColor.fireplace, SoundColor.fireplaceDark) }
        if n.contains("bowl") || n.contains("tibetan") { return (SoundColor.tibetanBowl, SoundColor.tibetanBowlDark) }
        if n.contains("cafe") || n.contains("coffee")  { return (SoundColor.cafe, SoundColor.cafeDark) }
        if n.contains("fan")             { return (SoundColor.fan, SoundColor.fanDark) }
        if n.contains("meditation") || n.contains("zen") { return (SoundColor.meditation, SoundColor.meditationDark) }
        return nil
    }

    /// Maps a UUID's bytes to a (primary, secondary) HSB pair.
    ///
    /// Bytes used:
    /// - `[0]`  → primary hue
    /// - `[4]`  → saturation perturbation
    /// - `[8]`  → hue spread (how far the secondary is from the primary)
    /// - `[12]` → brightness perturbation
    private static func uuidPalette(_ id: UUID) -> (Color, Color) {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let h1 = Double(bytes[0]) / 255.0
        let hueSpread = (Double(bytes[8]) / 255.0 - 0.5) * 0.22 // ±~40°
        let s = 0.42 + Double(bytes[4]) / 255.0 * 0.28          // 0.42–0.70
        let b = 0.78 + Double(bytes[12]) / 255.0 * 0.18         // 0.78–0.96

        let primary = Color(hue: h1, saturation: s, brightness: b)
        let h2 = (h1 + hueSpread + 1.0).truncatingRemainder(dividingBy: 1.0)
        let secondary = Color(hue: h2, saturation: s * 0.82, brightness: b * 0.74)
        return (primary, secondary)
    }
}
