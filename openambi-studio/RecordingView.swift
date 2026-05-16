import SwiftUI
import AVFoundation

/// The **Field** room — openambi 2.0's left-most page.
///
/// Two zones, one vertical scroll:
/// 1. **Capture** (top): the orb, level meter, timer, status, and primary
///    Record / Stop control. This is the hero of the screen — the first
///    thing the user sees, lit by Aurora colors.
/// 2. **Library** (below): your collection of saved recordings, rendered
///    by `RecordingsLibrarySection`. Today's `RecordingRow` UI is kept
///    verbatim; Phase 2.3 swaps it for palette-extracted circular cards.
///
/// Today the user had to dig into Settings → "My Recordings" to find their
/// captures. Field unifies the two intentions in a single room, which is
/// the IA promise of the 2.0 redesign.
struct RecordingView: View {
    @StateObject private var recordingManager = RecordingManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @Binding var selectedTab: Int // bound to ContentView's room index

    @State private var recordingResult: RecordingResult?
    @State private var showError = false
    @State private var errorMessage = ""

    // "Bring it in" flow state. The source sheet sits between the orb and
    // the Field Note save view; while ingest is running we keep the sheet
    // open and overlay a small editorial loader so the user can read what
    // we're doing ("listening to your scene…") without losing context.
    @State private var showSourcePicker = false
    @State private var isIngesting = false
    @State private var ingestedClip: IngestedVideo?
    @State private var ingestError: String?

    var body: some View {
        ZStack {
            // Background gradient — kept from the v1 capture screen.
            // Phase 2.6 will swap this for a time-of-day Aurora tint.
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        captureSection
                            .frame(minHeight: geo.size.height * 0.92)
                            .frame(maxWidth: .infinity)

                        Divider()
                            .background(AuroraColors.Stroke.hairline)
                            .padding(.horizontal, 36)

                        RecordingsLibrarySection()
                    }
                    // ContentView ignores safe area so the scene wash bleeds
                    // full-bleed; that flattens this GeometryReader's top
                    // inset to 0 and pulls the FieldHeader into the status
                    // bar / Dynamic Island. Read the window's real inset as
                    // a fallback so the header always lands beneath device
                    // chrome regardless of ancestor safe-area treatment.
                    .padding(.top, max(geo.safeAreaInsets.top, WindowMetrics.topInset))
                }
            }
        }
        .onAppear {
            // Pause all audio when the Field room appears so the user can
            // hear the room they're about to record.
            audioManager.pause()
        }
        .sheet(item: $recordingResult) { result in
            RecordingMetadataView(
                source: .recorded(result),
                onSave: { track in
                    audioManager.loadTracks(audioManager.tracks + [track])
                    recordingResult = nil
                    recordingManager.reset()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = Room.studio.rawValue
                    }
                },
                onCancel: {
                    recordingManager.cancelRecording()
                    recordingResult = nil
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = Room.studio.rawValue
                    }
                }
            )
            .environmentObject(audioManager)
        }
        .sheet(isPresented: $showSourcePicker) {
            ZStack {
                SourcePicker(
                    onPicked: { url in handleSourcePicked(url: url) },
                    onCancel: {
                        showSourcePicker = false
                        ingestError = nil
                    },
                    externalError: $ingestError
                )

                if isIngesting {
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        AuroraLoader.Modal(
                            title: "listening to your scene…",
                            subtitle: "lifting the audio out"
                        )
                    }
                    .transition(.opacity)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $ingestedClip) { clip in
            RecordingMetadataView(
                source: .imported(clip),
                onSave: { track in
                    audioManager.loadTracks(audioManager.tracks + [track])
                    ingestedClip = nil
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = Room.studio.rawValue
                    }
                },
                onCancel: {
                    VideoIngest.shared.cleanup(clip)
                    ingestedClip = nil
                }
            )
            .environmentObject(audioManager)
        }
        .alert("Recording Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: recordingManager.recordingState) { _, newState in
            if case .error(let message) = newState {
                errorMessage = message
                showError = true
            }
        }
    }

    /// Run ingest on the picked URL, then transition from the source sheet
    /// into the Field Note save view. Errors stay inside the source sheet
    /// as an editorial inline message — we never use a system alert here.
    private func handleSourcePicked(url: URL) {
        isIngesting = true
        ingestError = nil
        Task {
            do {
                let ingested = try await VideoIngest.shared.ingest(from: url)
                await MainActor.run {
                    isIngesting = false
                    showSourcePicker = false
                    ingestedClip = ingested
                    InstrumentFeedback.success()
                }
            } catch let error as VideoIngestError {
                await MainActor.run {
                    isIngesting = false
                    ingestError = error.errorDescription
                    InstrumentFeedback.warning()
                }
            } catch {
                await MainActor.run {
                    isIngesting = false
                    ingestError = "couldn't open this video — try another"
                    InstrumentFeedback.warning()
                }
            }
        }
    }

    // MARK: - Capture section

    /// The new capture orb (Phase 2.5). The waveform breathes around the
    /// record button so the orb itself becomes the visualization. The
    /// editorial header sits above the orb; the timer hangs just under
    /// it, and the status / hint sit at the bottom of the section.
    private var captureSection: some View {
        VStack(spacing: 28) {
            PlaceChip()
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text("Field")
                    .font(AuroraTypography.editorial(12, weight: .medium))
                    .kerning(2.4)
                    .textCase(.uppercase)
                    .foregroundColor(AuroraColors.TextOnAurora.tertiary)

                Text(captureHeadline)
                    .font(AuroraTypography.display(28, weight: .semibold))
                    .foregroundColor(AuroraColors.TextOnAurora.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer(minLength: 0)

            ZStack {
                CircularWaveformView(
                    level: recordingManager.audioLevel,
                    isRecording: isCurrentlyRecording
                )

                Button(action: handleRecordButtonTap) {
                    ZStack {
                        Circle()
                            .fill(buttonColor)
                            .frame(width: 84, height: 84)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: buttonColor.opacity(0.65), radius: 24, x: 0, y: 0)

                        Image(systemName: buttonIcon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(recordingManager.recordingState == .processing)
                .accessibilityLabel(buttonHintText)
            }
            .frame(height: 290)

            Text(recordingManager.formatDuration(recordingManager.recordingDuration))
                .font(AuroraTypography.mono(42, weight: .semibold))
                .foregroundColor(AuroraColors.TextOnAurora.primary)
                .monospacedDigit()
                .accessibilityLabel("Recording length \(recordingManager.formatDuration(recordingManager.recordingDuration))")

            statusText

            // A quiet sibling to the record orb. The orb is "the world coming
            // in" through the mic; this capsule is "or the world you already
            // captured, brought in from elsewhere." Hidden while recording so
            // it doesn't become a distraction.
            bringItInAffordance
                .opacity(isCurrentlyRecording ? 0 : 1)
                .animation(Motion.touch, value: isCurrentlyRecording)

            Spacer(minLength: 0)

            Text(buttonHintText)
                .font(AuroraTypography.ui(13, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                .padding(.bottom, 24)
        }
    }

    /// "or bring something in" — a ghost capsule under the record orb.
    /// Tap target is generous (≥44pt) but visually it's a hairline; it
    /// reads as a footnote to the orb, never as a competing CTA.
    private var bringItInAffordance: some View {
        Button(action: {
            InstrumentFeedback.tap()
            ingestError = nil
            showSourcePicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AuroraColors.TextOnAurora.secondary)
                Text("or bring something in")
                    .font(AuroraTypography.editorial(13, weight: .medium))
                    .foregroundColor(AuroraColors.TextOnAurora.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(
                Capsule(style: .continuous)
                    .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCurrentlyRecording)
        .accessibilityLabel("Bring a video in from your photos or files")
        .accessibilityHint("Opens a source picker to import an existing clip as a field note")
    }

    /// Single-line headline that adapts to recording state.
    private var captureHeadline: String {
        switch recordingManager.recordingState {
        case .recording: return "Listening to this room"
        case .processing: return "Saving the moment"
        case .completed: return "That's a take"
        case .paused: return "Held"
        case .error: return "Something interrupted us"
        case .idle: return "Capture this place"
        }
    }

    private var isCurrentlyRecording: Bool {
        if case .recording = recordingManager.recordingState { return true }
        return false
    }

    // MARK: - Computed Properties

    private var statusText: some View {
        Group {
            switch recordingManager.recordingState {
            case .idle:
                statusLine("Tap to start", color: AuroraColors.TextOnAurora.secondary)
            case .recording:
                statusLine("Recording", color: Color(red: 1.0, green: 0.38, blue: 0.42).opacity(0.95))
            case .processing:
                statusLine("Saving…", color: AuroraColors.TextOnAurora.secondary)
            case .completed:
                statusLine("Captured", color: Color(red: 0.45, green: 0.85, blue: 0.55))
            case .error(let message):
                statusLine(message, color: Color(red: 1.0, green: 0.38, blue: 0.42).opacity(0.95))
            case .paused:
                statusLine("Paused", color: AuroraColors.TextOnAurora.secondary)
            }
        }
    }

    private func statusLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AuroraTypography.editorial(15, weight: .medium))
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    private var buttonColor: Color {
        switch recordingManager.recordingState {
        case .recording:
            return .red
        default:
            return Color(red: 0.3, green: 0.72, blue: 1.0)
        }
    }

    private var buttonIcon: String {
        switch recordingManager.recordingState {
        case .recording:
            return "stop.fill"
        default:
            return "record.circle.fill"
        }
    }

    private var buttonHintText: String {
        switch recordingManager.recordingState {
        case .recording: return "Tap the orb to stop"
        case .processing: return "Holding the take…"
        default: return "Tap the orb to begin"
        }
    }

    // MARK: - Actions

    private func handleRecordButtonTap() {
        switch recordingManager.recordingState {
        case .idle:
            Task {
                do {
                    try await recordingManager.startRecording()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .recording:
            Task {
                do {
                    let result = try await recordingManager.stopRecording()
                    recordingResult = result
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        default:
            break
        }
    }
}

// LevelMeterView (the v1 horizontal bar meter) was removed in Phase 2.5;
// the capture orb now renders its own CircularWaveformView.

// MARK: - Preview
#Preview {
    RecordingView(selectedTab: .constant(Room.field.rawValue))
        .environmentObject(AudioManager())
        .environmentObject(AuthManager())
}
