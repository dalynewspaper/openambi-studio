import SwiftUI

/// The Phase 2.3 redesign of the library row.
///
/// Three differences from the old `RecordingRow`:
///
/// 1. **Palette-extracted circular thumbnail.** Every recording gets a
///    stable, deterministic 2-color identity courtesy of
///    `RecordingPalette`. No more identical blue/purple circles for
///    every track — the library now reads as a constellation.
///
/// 2. **Tap-thumbnail to blend into the live Studio mix.** The thumbnail
///    is a real audio affordance: tapping it toggles the track in the
///    Studio's mix without leaving the Field room. Tapping anywhere else
///    on the card still opens the editor sheet.
///
/// 3. **Drag-up-to-blend.** The thumbnail can be lifted upward. Cross
///    the threshold and the track is added to the mix with a celebratory
///    haptic; release short of the threshold and the thumbnail snaps
///    back home. This is the discoverable "instrument" gesture promised
///    by the redesign thesis — touch as performance, not just navigation.
///
/// Accessibility: VoiceOver users get a tap-toggle on the thumbnail (the
/// drag is a progressive enhancement). Reduce Motion shortens the snap.
struct LibraryCard: View {

    let recording: AudioTrack
    let isActiveInMix: Bool
    let onTapEdit: () -> Void
    let onToggleMix: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGSize = .zero
    @State private var didTriggerBlend: Bool = false

    private let thumbnailSize: CGFloat = 72
    private let dragLiftThreshold: CGFloat = -60

    var body: some View {
        Button(action: {
            InstrumentFeedback.tap()
            onTapEdit()
        }) {
            HStack(spacing: 18) {
                thumbnail
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .offset(dragOffset)
                    .scaleEffect(scaleForDrag)
                    .animation(reduceMotion ? .easeOut(duration: 0.18) : Motion.touch,
                               value: dragOffset)

                metadata

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AuroraColors.IconOnAurora.inactive)
                    .opacity(dragOffset == .zero ? 1 : 0)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recording.name), \(recording.category)")
        .accessibilityHint(isActiveInMix
                           ? "Currently in your mix. Double-tap to edit. Use the thumbnail to remove from mix."
                           : "Double-tap to edit. Use the thumbnail to add to mix.")
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        ZStack {
            // Palette gradient — the recording's color identity.
            Circle()
                .fill(RecordingPalette.gradient(for: recording))
                .overlay(
                    Circle()
                        .strokeBorder(
                            isActiveInMix
                            ? Color.white.opacity(0.85)
                            : AuroraColors.Stroke.edge,
                            lineWidth: isActiveInMix ? 2 : 1
                        )
                )
                .shadow(color: RecordingPalette.dominantColor(for: recording)
                            .opacity(isActiveInMix ? 0.7 : 0.35),
                        radius: isActiveInMix ? 16 : 8,
                        x: 0, y: 4)

            // Glyph from the recording's saved icon.
            Image(systemName: recording.icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                .opacity(dragLiftProgress > 0.5 ? 0 : 1)
                .animation(.easeOut(duration: 0.15), value: dragLiftProgress)

            // While the user is dragging up, fade in a "+" / "✓"
            // affordance so the gesture's intent is unambiguous.
            Image(systemName: isActiveInMix ? "minus" : "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .opacity(dragLiftProgress)
                .scaleEffect(0.85 + dragLiftProgress * 0.25)
                .shadow(color: RecordingPalette.dominantColor(for: recording)
                            .opacity(0.6),
                        radius: 8, x: 0, y: 0)
                .animation(.easeOut(duration: 0.12), value: dragLiftProgress)
        }
        .contentShape(Circle())
        .gesture(thumbnailTapGesture)
        .simultaneousGesture(thumbnailDragGesture)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(recording.name)
                .font(AuroraTypography.ui(17, weight: .semibold))
                .foregroundColor(AuroraColors.TextOnAurora.primary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if !recording.category.isEmpty {
                    Text(recording.category)
                        .font(AuroraTypography.ui(13, weight: .medium))
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }

                if let duration = recording.duration {
                    if !recording.category.isEmpty {
                        Text("•")
                            .foregroundColor(AuroraColors.TextOnAurora.quaternary)
                    }
                    Text(formatDuration(duration))
                        .font(AuroraTypography.mono(12))
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                } else if let recordedAt = recording.recordedAt {
                    if !recording.category.isEmpty {
                        Text("•")
                            .foregroundColor(AuroraColors.TextOnAurora.quaternary)
                    }
                    Text(recordedAt, style: .date)
                        .font(AuroraTypography.ui(12))
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }
            }

            if isActiveInMix {
                Text("In your mix")
                    .font(AuroraTypography.editorial(11, weight: .medium))
                    .kerning(1)
                    .textCase(.uppercase)
                    .foregroundColor(RecordingPalette.dominantColor(for: recording))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Card background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(isActiveInMix ? 0.85 : 0.7)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isActiveInMix
                        ? RecordingPalette.dominantColor(for: recording).opacity(0.55)
                        : AuroraColors.Stroke.hairline,
                        lineWidth: isActiveInMix ? 1.5 : 1
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }

    // MARK: - Gestures

    private var thumbnailTapGesture: some Gesture {
        TapGesture()
            .onEnded {
                let newActive = !isActiveInMix
                InstrumentFeedback.toggle(active: newActive)
                onToggleMix(newActive)
            }
    }

    /// Vertical drag on the thumbnail. Pushing up past `dragLiftThreshold`
    /// triggers the blend; release before the threshold snaps it back home.
    private var thumbnailDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                // Only respond to upward, predominantly-vertical drags so
                // we don't fight the parent ScrollView on diagonal motion.
                guard value.translation.height < 0,
                      abs(value.translation.height) > abs(value.translation.width)
                else { return }
                dragOffset = CGSize(width: 0, height: value.translation.height)

                if !didTriggerBlend, value.translation.height <= dragLiftThreshold {
                    didTriggerBlend = true
                    let newActive = !isActiveInMix
                    InstrumentFeedback.solo(active: newActive)
                    onToggleMix(newActive)
                }
            }
            .onEnded { _ in
                withAnimation(reduceMotion
                              ? .easeOut(duration: 0.22)
                              : .interpolatingSpring(stiffness: 240, damping: 22)) {
                    dragOffset = .zero
                }
                didTriggerBlend = false
            }
    }

    /// 0…1 indicator of how close we are to triggering the lift.
    private var dragLiftProgress: CGFloat {
        let raw = min(1, max(0, -dragOffset.height / -dragLiftThreshold))
        return raw
    }

    private var scaleForDrag: CGFloat {
        1 + dragLiftProgress * 0.08
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %ds", m, s) }
        return String(format: "%ds", s)
    }
}
