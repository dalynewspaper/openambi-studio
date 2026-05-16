import SwiftUI

/// Top-of-Studio editorial header.
///
/// Parity with the Field room: the top of the screen tells you where
/// you are in the IA and what is happening right now. In the Studio,
/// "what is happening right now" is the live mix — so the header reads
/// like a now-playing strip but in editorial vocabulary:
///
///     STUDIO
///     Layered: rain · ocean · wind         Lisbon · 14:42 · sea breeze
///
/// When nothing is playing the line softens to "A quiet room", which
/// frames the scene as intentional rather than empty.
///
/// The header is intentionally a single line of content (a small kicker
/// over a meaningful subtitle, with the place chip on the trailing
/// edge). It does not steal the eye from the constellation/grid; it
/// gives you context without becoming the subject.
struct StudioHeader: View {

    let activeTracks: [AudioTrack]

    @Environment(\.dominantSoundColor) private var dominant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    // "Now playing" indicator dot — picks up the live
                    // mix's dominant color via @Environment(.dominantSoundColor)
                    // and breathes when there is something to listen to.
                    // When silent it stays small and dim so the dot reads
                    // as 'standby' rather than missing.
                    Circle()
                        .fill(dominant)
                        .frame(width: isLive ? 7 : 5, height: isLive ? 7 : 5)
                        .opacity(dotOpacity)
                        .shadow(color: dominant.opacity(isLive ? 0.55 : 0), radius: isLive ? 6 : 0)
                        .accessibilityHidden(true)

                    Text("Studio")
                        .font(AuroraTypography.editorial(11, weight: .medium))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }

                Text(sceneMood)
                    .font(AuroraTypography.editorial(15, weight: .semibold))
                    .foregroundColor(AuroraColors.TextOnAurora.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 12)

            PlaceChip()
                .layoutPriority(0)
        }
        .padding(.horizontal, 18)
        .onAppear { startBreathLoopIfNeeded() }
        .onChange(of: isLive) { _, _ in startBreathLoopIfNeeded() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Studio. \(accessibilityMood)")
    }

    private var isLive: Bool { !activeTracks.isEmpty }

    /// Static opacity when the room is silent or motion is reduced; breathes
    /// between 0.55 and 0.95 otherwise. The pulse value is the actual driver.
    private var dotOpacity: Double {
        guard isLive else { return 0.22 }
        if reduceMotion { return 0.78 }
        return pulse ? 0.95 : 0.55
    }

    private func startBreathLoopIfNeeded() {
        guard isLive, !reduceMotion else { return }
        // Long, calm autoreversing breath. Driving from a single `pulse`
        // boolean with a repeating autoreverse animation keeps the loop
        // confined to this view's render cycle.
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    // MARK: - Mood composition

    /// Visible scene mood line. The intent is editorial calm —
    /// never a literal "0 active tracks", always a phrase.
    private var sceneMood: String {
        switch activeTracks.count {
        case 0:
            return "A quiet room"
        case 1:
            return activeTracks[0].name
        case 2:
            return "\(activeTracks[0].name) · \(activeTracks[1].name)"
        case 3:
            return activeTracks.prefix(3).map { $0.name }.joined(separator: " · ")
        default:
            let head = activeTracks.prefix(2).map { $0.name }.joined(separator: " · ")
            let extra = activeTracks.count - 2
            return "\(head) · +\(extra) more"
        }
    }

    private var accessibilityMood: String {
        switch activeTracks.count {
        case 0:
            return "A quiet room. No sounds playing."
        case 1:
            return "One sound playing: \(activeTracks[0].name)."
        default:
            let names = activeTracks.map { $0.name }.joined(separator: ", ")
            return "\(activeTracks.count) sounds layered: \(names)."
        }
    }
}

#if DEBUG
private func _previewTrack(_ name: String, _ icon: String) -> AudioTrack {
    AudioTrack(
        name: name,
        category: "nature",
        icon: icon,
        audioUrl: "",
        isActive: true,
        volume: 0.5
    )
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        VStack(spacing: 28) {
            StudioHeader(activeTracks: [])
            StudioHeader(activeTracks: [_previewTrack("Rain", "cloud.rain.fill")])
            StudioHeader(activeTracks: [
                _previewTrack("Rain", "cloud.rain"),
                _previewTrack("Ocean", "water.waves"),
                _previewTrack("Wind", "wind"),
                _previewTrack("Birds", "bird")
            ])
            Spacer()
        }
        .padding(.top, 60)
    }
}
#endif
