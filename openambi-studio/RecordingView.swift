import SwiftUI
import AVFoundation

struct RecordingView: View {
    @StateObject private var recordingManager = RecordingManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @Binding var selectedTab: Int // Binding to navigate back to main tab
    
    @State private var recordingResult: RecordingResult?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                // Pause all audio when recording screen appears
                audioManager.pause()
            }
            
            VStack(spacing: 40) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("Record Sound")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Recording visualization
                VStack(spacing: 30) {
                    // Level meter visualization
                    LevelMeterView(level: recordingManager.audioLevel)
                        .frame(height: 200)
                    
                    // Timer
                    Text(recordingManager.formatDuration(recordingManager.recordingDuration))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    // Status text
                    statusText
                }
                
                Spacer()
                
                // Control buttons
                VStack(spacing: 20) {
                    // Record/Stop button
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
                    
                    // Hint text
                    Text(buttonHintText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(item: $recordingResult) { result in
            RecordingMetadataView(
                recordingResult: result,
                onSave: { track in
                    print("💾 Recording saved callback: \(track.name) (ID: \(track.id.uuidString))")
                    // Add track to AudioManager
                    audioManager.loadTracks(audioManager.tracks + [track])
                    // Dismiss the sheet
                    recordingResult = nil
                    // Reset recording state to allow new recording
                    recordingManager.reset()
                    // Navigate back to main tab (index 1)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                },
                onCancel: {
                    recordingManager.cancelRecording()
                    // Dismiss the sheet
                    recordingResult = nil
                    // Navigate back to main tab (index 1)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                }
            )
            .environmentObject(audioManager)
        }
        .alert("Recording Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                // Alert dismissed - no navigation needed, user can continue recording
            }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: recordingManager.recordingState) { oldState, newState in
            if case .error(let message) = newState {
                errorMessage = message
                showError = true
            }
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
            return Color(red: 0.3, green: 0.72, blue: 1.0) // Blue
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
                    // Set result - this will automatically show the sheet via .sheet(item:)
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
            // Calculate height based on how much above threshold
            let excess = normalizedLevel - threshold
            let maxHeight: CGFloat = 200
            let minHeight: CGFloat = 8
            
            // Bars get taller as we go right
            let baseHeight = minHeight + (CGFloat(index) / 30.0) * (maxHeight - minHeight)
            
            // Add extra height if level exceeds threshold
            let extraHeight = excess * 20
            
            return min(baseHeight + extraHeight, maxHeight)
        } else {
            return 8 // Minimum height
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
    RecordingView(selectedTab: .constant(1))
        .environmentObject(AudioManager())
}

