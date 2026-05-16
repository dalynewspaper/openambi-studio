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
                    .padding(.top, geo.safeAreaInsets.top)
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
                recordingResult: result,
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

    // MARK: - Capture section

    private var captureSection: some View {
        VStack(spacing: 40) {
            HStack {
                Spacer()
                Text("Record Sound")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer(minLength: 0)

            VStack(spacing: 30) {
                LevelMeterView(level: recordingManager.audioLevel)
                    .frame(height: 200)

                Text(recordingManager.formatDuration(recordingManager.recordingDuration))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()

                statusText
            }

            Spacer(minLength: 0)

            VStack(spacing: 20) {
                Button(action: handleRecordButtonTap) {
                    ZStack {
                        Circle()
                            .fill(buttonColor)
                            .frame(width: 80, height: 80)
                            .shadow(color: buttonColor.opacity(0.5), radius: 20, x: 0, y: 0)

                        Image(systemName: buttonIcon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(recordingManager.recordingState == .processing)

                Text(buttonHintText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Computed Properties

    private var statusText: some View {
        Group {
            switch recordingManager.recordingState {
            case .idle:
                Text("Tap to start recording")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            case .recording:
                Text("Recording...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red.opacity(0.9))
            case .processing:
                Text("Processing...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            case .completed:
                Text("Recording complete")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green.opacity(0.9))
            case .error(let message):
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red.opacity(0.9))
            case .paused:
                Text("Paused")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
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
        case .recording:
            return "Tap to stop recording"
        case .processing:
            return "Processing your recording..."
        default:
            return "Tap to start recording"
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

// MARK: - Level Meter View
struct LevelMeterView: View {
    let level: Double // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: (geometry.size.width - 116) / 30, height: barHeight(for: index))
                        .animation(.spring(response: 0.1, dampingFraction: 0.6), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Double(index) / 30.0
        let normalizedLevel = level

        if normalizedLevel >= threshold {
            let excess = normalizedLevel - threshold
            let maxHeight: CGFloat = 200
            let minHeight: CGFloat = 8
            let baseHeight = minHeight + (CGFloat(index) / 30.0) * (maxHeight - minHeight)
            let extraHeight = excess * 20
            return min(baseHeight + extraHeight, maxHeight)
        } else {
            return 8
        }
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Double(index) / 30.0
        if level >= threshold {
            if index < 20 {
                return .green
            } else if index < 26 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return .white.opacity(0.2)
        }
    }
}

// MARK: - Preview
#Preview {
    RecordingView(selectedTab: .constant(Room.field.rawValue))
        .environmentObject(AudioManager())
        .environmentObject(AuthManager())
}
