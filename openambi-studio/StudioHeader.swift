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

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Studio")
                    .font(AuroraTypography.editorial(11, weight: .medium))
                    .kerning(2.4)
                    .textCase(.uppercase)
                    .foregroundColor(AuroraColors.TextOnAurora.tertiary)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Studio. \(accessibilityMood)")
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
