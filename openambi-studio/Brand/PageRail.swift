import SwiftUI

/// The bottom-of-screen pagination indicator for the three rooms.
///
/// Replaces SwiftUI's system `TabView` page dots with a quieter, more
/// editorial vocabulary:
/// - Three short capsule "bars" — one per room.
/// - The active bar widens, brightens, and picks up a glow tinted by the
///   current `@Environment(\.dominantSoundColor)` (set by the Studio).
/// - Each bar is a touch target; tapping navigates directly to that room.
/// - Above the active bar, the room's display name fades in for ~1.4s
///   after every switch so the user always knows which room they're in.
///
/// The rail itself is *very* small visually; the goal is presence without
/// noise. Tap-or-swipe parity ensures discoverability of the side rooms.
struct PageRail: View {

    /// The active room index. Bound to the same `Int` that the parent
    /// `TabView` uses, so existing children (`RecordingView`, etc.) that
    /// take a `Binding<Int>` don't need to be changed.
    @Binding var selectedIndex: Int

    @Environment(\.dominantSoundColor) private var dominant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the room name should be visible. Auto-fades on every change.
    @State private var labelVisible: Bool = false
    @State private var revealTask: Task<Void, Never>? = nil

    // Visual constants — kept here to make the rail's vocabulary explicit.
    private let inactiveWidth: CGFloat = 18
    private let activeWidth: CGFloat = 30
    private let barHeight: CGFloat = 3
    private let barSpacing: CGFloat = 14
    private let labelGap: CGFloat = 10

    var body: some View {
        VStack(spacing: labelGap) {
            // Room label above the active bar — fades after each switch
            // so first-time users learn the IA without a tutorial.
            Text(activeRoom.displayName)
                .font(AuroraTypography.editorial(13, weight: .medium))
                .kerning(1.6)
                .foregroundColor(AuroraColors.TextOnAurora.primary)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 1)
                .opacity(labelVisible ? 1 : 0)
                .accessibilityHidden(true)

            HStack(spacing: barSpacing) {
                ForEach(Room.allCases) { room in
                    bar(for: room)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(railBackground)
        }
        .accessibilityElement(children: .contain)
        .onAppear { revealLabel() }
        .onChange(of: selectedIndex) { _, _ in revealLabel() }
    }

    // MARK: - Bar

    private func bar(for room: Room) -> some View {
        let isSelected = (room.rawValue == selectedIndex)
        return Capsule(style: .continuous)
            .fill(isSelected
                  ? AnyShapeStyle(activeFill)
                  : AnyShapeStyle(AuroraColors.Stroke.edge))
            .frame(width: isSelected ? activeWidth : inactiveWidth,
                   height: barHeight)
            .shadow(color: isSelected ? dominant.opacity(0.55) : .clear,
                    radius: isSelected ? 8 : 0,
                    x: 0, y: 0)
            .contentShape(Rectangle().inset(by: -14))
            .onTapGesture {
                guard !isSelected else { return }
                InstrumentFeedback.tap()
                withAnimation(reduceMotion ? .easeOut(duration: 0.22) : Motion.touch) {
                    selectedIndex = room.rawValue
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.22) : Motion.touch,
                       value: selectedIndex)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(room.displayName)
            .accessibilityValue(room.subtitle)
            .accessibilityHint("Tap to switch to the \(room.displayName) room")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var activeRoom: Room {
        Room(rawValue: selectedIndex) ?? .studio
    }

    /// Active bar fill: dominant-color → white highlight gradient. Reads
    /// alive against any scene because the gradient stops adapt with the mix.
    private var activeFill: LinearGradient {
        LinearGradient(
            colors: [
                dominant.opacity(0.95),
                Color.white.opacity(0.95),
                dominant.opacity(0.75)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// A subtle pill behind the bars so the rail is legible against any
    /// scene material — even a fully-bright video background.
    private var railBackground: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.55)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }

    // MARK: - Reveal label

    private func revealLabel() {
        revealTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) { labelVisible = true }
        revealTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000) // 1.4s
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.45)) { labelVisible = false }
        }
    }
}

#if DEBUG
private struct PageRailPreviewHost: View {
    @State var selected: Int = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            VStack {
                Spacer()
                Text(Room(rawValue: selected)?.displayName ?? "—")
                    .font(AuroraTypography.display(48))
                    .foregroundColor(.white)
                Spacer()
            }
            PageRail(selectedIndex: $selected)
                .padding(.bottom, 24)
        }
        .environment(\.dominantSoundColor, SoundColor.rain)
    }
}

#Preview("PageRail") {
    PageRailPreviewHost()
}
#endif
