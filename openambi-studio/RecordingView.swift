import SwiftUI
import AVFoundation
import UIKit
import PhotosUI

struct RecordingView: View {
    @StateObject private var recordingManager = RecordingManager.shared
    @StateObject private var permissionsManager = PermissionsManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @Binding var selectedTab: Int // Binding to navigate back to main tab
    
    @State private var recordingResult: RecordingResult?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showMicrophoneSettingsAlert = false
    @State private var showVideoPicker = false
    @State private var videoPickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showDocumentVideoPicker = false
    @State private var pulsePhase: Double = 0
    
    private var isRecording: Bool {
        if case .recording = recordingManager.recordingState { return true }
        return false
    }
    
    var body: some View {
        ZStack {
            // Background - consistent with app theme
            AppTheme.background
                .ignoresSafeArea()
                .onAppear {
                    // Pause all audio when recording screen appears
                    audioManager.pause()
                    // Update permission states
                    permissionsManager.updatePermissionStates()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Central recording orb + visualization
                ZStack {
                    // Ambient waveform ring around record button
                    CircularWaveformView(level: recordingManager.audioLevel, isRecording: isRecording)
                        .frame(width: 240, height: 240)
                    
                    // Record/Stop button - glass treatment
                    Button(action: {
                        handleRecordButtonTap()
                    }) {
                        ZStack {
                            // Glass circle base
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    buttonColor.opacity(isRecording ? 0.5 : 0.25),
                                                    buttonColor.opacity(isRecording ? 0.3 : 0.1),
                                                    .clear
                                                ],
                                                center: .center,
                                                startRadius: 10,
                                                endRadius: 48
                                            )
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    buttonColor.opacity(isRecording ? 0.9 : 0.5),
                                                    buttonColor.opacity(isRecording ? 0.6 : 0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2.5
                                        )
                                )
                                .shadow(color: buttonColor.opacity(isRecording ? 0.6 : 0.3), radius: isRecording ? 25 : 12, x: 0, y: 0)
                            
                            // Icon
                            Image(systemName: buttonIcon)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled({
                        if case .processing = recordingManager.recordingState { return true }
                        if case .countdown = recordingManager.recordingState { return true }
                        return false
                    }())
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(isRecording ? 1.05 : 1.0)
                    .animation(AppTheme.Animation.liquidSpring, value: isRecording)
                }
                
                Spacer()
                    .frame(height: 40)
                
                // Timer or Countdown
                VStack(spacing: 12) {
                    if case .countdown(let count) = recordingManager.recordingState {
                        Text("\(count)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
                    } else {
                        Text(recordingManager.formatDuration(recordingManager.recordingDuration))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    
                    // Status text
                    statusText
                }
                
                Spacer()
                
                // Bottom controls area - glass card
                VStack(spacing: 16) {
                    // Hint text
                    Text(buttonHintText)
                        .font(.system(size: AppTypography.caption, weight: .medium))
                        .foregroundColor(AppColors.tertiaryText)

                    // Video import / capture
                    HStack(spacing: 12) {
                        Button(action: {
                            startVideoCapture()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Camera")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(videoSecondaryButtonBackground)
                        }
                        .disabled(isVideoActionDisabled)
                        .opacity(isVideoActionDisabled ? 0.4 : 1.0)

                        PhotosPicker(selection: $photoPickerItem, matching: .videos, photoLibrary: .shared()) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Photos")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(videoSecondaryButtonBackground)
                        }
                        .disabled(isVideoActionDisabled)
                        .opacity(isVideoActionDisabled ? 0.4 : 1.0)

                        Button(action: {
                            showDocumentVideoPicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Files")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(videoSecondaryButtonBackground)
                        }
                        .disabled(isVideoActionDisabled)
                        .opacity(isVideoActionDisabled ? 0.4 : 1.0)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, 60)
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
                errorMessage = ""
            }
        } message: {
            Text(errorMessage.isEmpty ? "An unknown error occurred" : errorMessage)
        }
        .alert("Microphone Permission Required", isPresented: $showMicrophoneSettingsAlert) {
            Button("Settings") {
                PermissionsManager.shared.openMicrophoneSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("OpenAmbi needs microphone access to record sounds. Please enable it in Settings.")
        }
        .onChange(of: recordingManager.recordingState) { oldState, newState in
            if case .error(let message) = newState {
                errorMessage = message
                showError = true
            }
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(
                sourceType: videoPickerSourceType,
                onPicked: { url in
                    showVideoPicker = false
                    handleVideoPicked(url)
                },
                onCancelled: {
                    showVideoPicker = false
                }
            )
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let transferable = try await item.loadTransferable(type: VideoPickerTransferable.self) {
                        await MainActor.run {
                            photoPickerItem = nil
                            handleVideoPicked(transferable.url)
                        }
                    } else {
                        await MainActor.run { photoPickerItem = nil }
                    }
                } catch {
                    await MainActor.run {
                        photoPickerItem = nil
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentVideoPicker) {
            DocumentVideoPicker(
                onPicked: { url in
                    showDocumentVideoPicker = false
                    handleVideoPicked(url)
                },
                onCancel: {
                    showDocumentVideoPicker = false
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: some View {
        Group {
            switch recordingManager.recordingState {
            case .idle:
                Text("Tap to start recording")
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            case .countdown:
                Text("Get ready...")
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            case .recording:
                Text("Recording...")
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(.red.opacity(0.9))
            case .processing:
                Text("Processing...")
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            case .completed:
                Text("Recording complete")
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(.green.opacity(0.9))
            case .error(let message):
                Text(message)
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(.red.opacity(0.9))
            case .paused:
                Text("Paused")
                    .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
    
    private var buttonColor: Color {
        switch recordingManager.recordingState {
        case .recording:
            return .red
        default:
            return SoundColor.rain
        }
    }
    
    private var buttonIcon: String {
        switch recordingManager.recordingState {
        case .recording:
            return "stop.fill"
        default:
            return "mic.fill"
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

    private var videoSecondaryButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var isVideoActionDisabled: Bool {
        if case .processing = recordingManager.recordingState { return true }
        if case .countdown = recordingManager.recordingState { return true }
        if case .recording = recordingManager.recordingState { return true }
        return false
    }
    
    // MARK: - Actions
    
    private func handleRecordButtonTap() {
        print("🎙️ Record button tapped, current state: \(recordingManager.recordingState)")
        
        switch recordingManager.recordingState {
        case .idle:
            print("🎙️ Starting recording with countdown...")
            Task { @MainActor in
                // Check permission first
                let hasPermission = await recordingManager.checkMicrophonePermission()
                if !hasPermission {
                    // Check if it was denied (user needs to go to Settings)
                    if !permissionsManager.hasMicrophonePermission {
                        showMicrophoneSettingsAlert = true
                        return
                    }
                }
                
                do {
                    try await recordingManager.startRecording()
                    print("✅ Recording started successfully")
                } catch RecordingError.permissionDenied {
                    print("❌ Recording failed: Permission denied")
                    showMicrophoneSettingsAlert = true
                } catch {
                    print("❌ Recording failed: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .countdown:
            // Don't allow canceling during countdown - let it finish
            break
        case .recording:
            print("🎙️ Stopping recording...")
            Task { @MainActor in
                do {
                    let result = try await recordingManager.stopRecording()
                    print("✅ Recording stopped successfully")
                    // Set result - this will automatically show the sheet via .sheet(item:)
                    recordingResult = result
                } catch {
                    print("❌ Stop recording failed: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        default:
            print("⚠️ Button tapped but state is \(recordingManager.recordingState), ignoring")
            break
        }
    }

    private func startVideoCapture() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "Camera is not available on this device."
            showError = true
            return
        }

        videoPickerSourceType = .camera
        showVideoPicker = true
    }

    private func handleVideoPicked(_ url: URL) {
        Task { @MainActor in
            do {
                let result = try await recordingManager.processVideoImport(videoURL: url)
                recordingResult = result
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Circular Waveform Visualization
/// Ambient-style circular waveform ring that pulses with audio level
struct CircularWaveformView: View {
    let level: Double // 0.0 to 1.0
    let isRecording: Bool
    
    @State private var breathePhase: Double = 0
    
    private let ringCount = 3
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = min(geometry.size.width, geometry.size.height) / 2
            
            ZStack {
                // Outer glow ring (ambient breathing)
                Circle()
                    .stroke(
                        RadialGradient(
                            colors: [
                                ringColor.opacity(isRecording ? 0.4 * level : 0.1),
                                ringColor.opacity(isRecording ? 0.15 * level : 0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: maxRadius * 0.6,
                            endRadius: maxRadius
                        ),
                        lineWidth: 40
                    )
                    .frame(width: maxRadius * 2, height: maxRadius * 2)
                    .scaleEffect(1.0 + (isRecording ? level * 0.12 : breatheScale * 0.04))
                    .blur(radius: 12)
                    .position(center)
                
                // Waveform segments around the circle
                ForEach(0..<48, id: \.self) { index in
                    let angle = (Double(index) / 48.0) * 2 * .pi - .pi / 2
                    let segmentLevel = segmentHeight(for: index)
                    let innerRadius = maxRadius * 0.45
                    let outerRadius = innerRadius + segmentLevel * maxRadius * 0.3
                    
                    // Segment line
                    Path { path in
                        let innerPoint = CGPoint(
                            x: center.x + cos(angle) * innerRadius,
                            y: center.y + sin(angle) * innerRadius
                        )
                        let outerPoint = CGPoint(
                            x: center.x + cos(angle) * outerRadius,
                            y: center.y + sin(angle) * outerRadius
                        )
                        path.move(to: innerPoint)
                        path.addLine(to: outerPoint)
                    }
                    .stroke(
                        segmentColor(for: index),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: level)
                }
                
                // Inner ring (subtle guide)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: maxRadius * 0.9, height: maxRadius * 0.9)
                    .position(center)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
        }
    }
    
    private var breatheScale: Double {
        breathePhase
    }
    
    private var ringColor: Color {
        isRecording ? .red : SoundColor.rain
    }
    
    private func segmentHeight(for index: Int) -> Double {
        if !isRecording && level <= 0.01 {
            // Idle state: subtle ambient breathing
            let angle = Double(index) / 48.0 * 2 * .pi
            return 0.15 + sin(angle * 3 + breathePhase * .pi * 2) * 0.08
        }
        
        // Recording state: respond to audio level with some variation per segment
        let baseLevel = level
        let variation = sin(Double(index) * 0.8 + level * 10) * 0.3
        let segmentLevel = baseLevel + variation * baseLevel
        return max(0.08, min(1.0, segmentLevel))
    }
    
    private func segmentColor(for index: Int) -> Color {
        let segHeight = segmentHeight(for: index)
        
        if !isRecording {
            return SoundColor.rain.opacity(0.3 + segHeight * 0.4)
        }
        
        // Color shifts from blue to warm as level increases
        if segHeight > 0.85 {
            return Color.red.opacity(0.8)
        } else if segHeight > 0.6 {
            return SoundColor.fireplace.opacity(0.7)
        } else {
            return SoundColor.rain.opacity(0.4 + segHeight * 0.5)
        }
    }
}

// MARK: - Preview
#Preview {
    RecordingView(selectedTab: .constant(1))
        .environmentObject(AudioManager())
}
