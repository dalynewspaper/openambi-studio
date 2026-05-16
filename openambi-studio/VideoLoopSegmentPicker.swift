import SwiftUI
import AVKit
import AVFoundation

/// Lets the user slide a **90-second** window along the full clip before we
/// extract audio + trim video for upload. Short clips use the whole duration.
struct VideoLoopSegmentPicker: View {
    let pending: PendingVideoImport
    /// Called with loop start time in seconds (relative to file start).
    let onConfirm: (TimeInterval) -> Void
    let onCancel: () -> Void

    /// While `finalizeImport` runs on the main actor–scheduled task.
    let isWorking: Bool

    @State private var loopStart: TimeInterval = 0
    @State private var anchorLoopStart: TimeInterval = 0
    @State private var isDraggingWindow = false

    @StateObject private var previewHolder: LoopPreviewPlayerHolder

    init(
        pending: PendingVideoImport,
        isWorking: Bool,
        onConfirm: @escaping (TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.pending = pending
        self.isWorking = isWorking
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let holder = LoopPreviewPlayerHolder(url: pending.copiedVideoURL)
        _previewHolder = StateObject(wrappedValue: holder)
    }

    private var loopSeconds: TimeInterval {
        pending.effectiveLoopSeconds
    }

    private var maxStart: TimeInterval {
        pending.maxLoopStart
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        headerCopy

                        previewVideo
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        sectionKicker("along the clip")
                        timelineStrip

                        timeReadout

                        Text(
                            pending.sourceDuration <= PendingVideoImport.loopExportSeconds
                                ? "this one's shorter than 90 seconds — we'll use all of it."
                                : "drag the window to pick which \(Int(loopSeconds)) seconds become your ambient loop."
                        )
                        .font(AuroraTypography.editorial(13, weight: .regular))
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 24)

                        Button(action: {
                            InstrumentFeedback.tap()
                            onConfirm(loopStart)
                        }) {
                            Text("use this loop")
                                .font(AuroraTypography.editorial(16, weight: .semibold))
                                .foregroundColor(AuroraColors.TextOnAurora.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.85)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                        .opacity(isWorking ? 0.45 : 1)

                        Spacer(minLength: WindowMetrics.bottomInset + 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, WindowMetrics.topInset + 8)
                }

                if isWorking {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    AuroraLoader.Modal(
                        title: "building your loop…",
                        subtitle: "trimming audio & picture"
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        InstrumentFeedback.tap()
                        onCancel()
                    }
                    .foregroundColor(AuroraColors.TextOnAurora.secondary)
                    .disabled(isWorking)
                }
            }
        }
        .onAppear {
            loopStart = maxStart > 0 ? maxStart / 2 : 0
            anchorLoopStart = loopStart
            previewHolder.seek(to: loopStart)
        }
        .onChange(of: loopStart) { _, newStart in
            previewHolder.seek(to: newStart)
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("choose your loop")
                .font(AuroraTypography.editorial(11, weight: .medium))
                .kerning(2.4)
                .textCase(.uppercase)
                .foregroundColor(AuroraColors.TextOnAurora.tertiary)

            Text("\(Int(loopSeconds)) seconds along \(formatClock(pending.sourceDuration))")
                .font(AuroraTypography.editorial(22, weight: .semibold))
                .foregroundColor(AuroraColors.TextOnAurora.primary)
        }
    }

    private var previewVideo: some View {
        VideoPlayer(player: previewHolder.player)
            .frame(height: 196)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
            )
    }

    private var timelineStrip: some View {
        GeometryReader { geo in
            let trackW = geo.size.width
            let W = loopSeconds
            let D = max(pending.sourceDuration, 0.001)
            let selectionW = D > W ? trackW * CGFloat(W / D) : trackW
            let travel = max(trackW - selectionW, 0)
            let xPos = maxStart <= 0 ? 0 : CGFloat(loopStart / maxStart) * travel

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 40)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .frame(width: max(selectionW, 44), height: 46)
                    .offset(x: xPos)
                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                guard travel > 0 else { return }
                                if !isDraggingWindow {
                                    isDraggingWindow = true
                                    anchorLoopStart = loopStart
                                    InstrumentFeedback.dragStart()
                                }
                                let deltaTime = (g.translation.width / travel) * maxStart
                                loopStart = min(max(anchorLoopStart + TimeInterval(deltaTime), 0), maxStart)
                            }
                            .onEnded { _ in
                                if isDraggingWindow {
                                    InstrumentFeedback.dragEnd()
                                }
                                isDraggingWindow = false
                                anchorLoopStart = loopStart
                            }
                    )
            }
            .frame(height: 52)
        }
        .frame(height: 52)
    }

    private var timeReadout: some View {
        HStack {
            Text(formatClock(loopStart))
                .font(AuroraTypography.mono(13, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
            Spacer()
            Text(formatClock(loopStart + loopSeconds))
                .font(AuroraTypography.mono(13, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
        }
    }

    private func sectionKicker(_ text: String) -> some View {
        Text(text)
            .font(AuroraTypography.editorial(11, weight: .medium))
            .kerning(1.8)
            .textCase(.uppercase)
            .foregroundColor(AuroraColors.TextOnAurora.tertiary)
    }

    private func formatClock(_ seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        let m = Int(s) / 60
        let r = Int(s) % 60
        return String(format: "%d:%02d", m, r)
    }
}

// MARK: - Preview player

private final class LoopPreviewPlayerHolder: ObservableObject {
    let player: AVPlayer

    init(url: URL) {
        self.player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .pause
    }

    func seek(to seconds: TimeInterval) {
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    deinit {
        player.pause()
    }
}
