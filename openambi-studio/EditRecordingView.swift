import SwiftUI
import AVFoundation

struct EditRecordingView: View {
    let recording: AudioTrack
    let onSave: (AudioTrack) -> Void
    let onDelete: () -> Void
    
    @StateObject private var supabaseService = SupabaseService()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var compositionSession: CompositionSessionStore
    
    @State private var title: String
    @State private var category: String
    @State private var description: String
    @State private var selectedIcon: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var isPreviewing = false
    @State private var previewPlayer: AVPlayer?
    @State private var isTitleEditing = false
    @State private var isTitleFocused = false
    @State private var isDescriptionExpanded = false
    @State private var iconCarouselOffset: CGFloat = 0
    @State private var pendingVideoRemoval = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let categories = [
        "My Recordings",
        "Nature",
        "Indoor",
        "Urban",
        "Water",
        "Wind",
        "Fire",
        "Custom"
    ]
    
    private let availableIcons = [
        "waveform", "waveform.circle.fill", "music.note",
        "cloud.rain.fill", "cloud.bolt.fill", "cloud.fill",
        "tree.fill", "leaf.fill", "bird.fill",
        "water.waves", "flame.fill", "sparkles",
        "house.fill", "building.2.fill", "car.fill",
        "cup.and.saucer.fill", "clock.fill", "star.fill",
        "heart.fill", "moon.fill", "sun.max.fill",
        "mic.fill", "speaker.wave.3.fill", "headphones"
    ]
    
    init(recording: AudioTrack, onSave: @escaping (AudioTrack) -> Void, onDelete: @escaping () -> Void) {
        self.recording = recording
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: recording.name)
        _category = State(initialValue: recording.category)
        _description = State(initialValue: recording.description ?? "")
        _selectedIcon = State(initialValue: recording.icon)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - use AppTheme for consistency
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Hero recording display
                        heroRecordingSection
                        
                        // Sound Identity (icon selection)
                        soundIdentitySection
                        
                        // Metadata form
                        metadataForm

                        if hasRemovableCloudVideo {
                            videoBackgroundEditSection
                        }
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
                .onTapGesture {
                    // Dismiss title editing when tapping outside
                    if isTitleEditing {
                        withAnimation(AppTheme.Animation.smooth) {
                            isTitleEditing = false
                            isTitleFocused = false
                        }
                    }
                }
            }
            .navigationTitle("Edit Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Remove Recording", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Recording", role: .destructive) {
                handleDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let durationText = recording.duration.map { formatDuration($0) } ?? ""
            Text("Remove \"\(title)\"\(durationText.isEmpty ? "" : " (\(durationText))")? This recording will be removed from your library.")
        }
    }
    
    private var hasRemovableCloudVideo: Bool {
        guard recording.isUserRecording else { return false }
        guard let v = recording.videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty else { return false }
        return v.lowercased().hasPrefix("http")
    }

    private var videoBackgroundEditSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Mix video background", systemImage: "rectangle.on.rectangle")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            if pendingVideoRemoval {
                Text("The synced video will be removed from cloud storage when you save.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.secondaryText)

                Button(action: {
                    pendingVideoRemoval = false
                }) {
                    Text("Keep video background")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SoundColor.rain)
                }
                .buttonStyle(.plain)
            } else {
                Text("Shown behind your mix when you choose “Use as Mix Background” on the soundscape.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.secondaryText)

                Button(role: .destructive, action: {
                    pendingVideoRemoval = true
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Remove video from cloud")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .liquidGlass(intensity: 0.65, cornerRadius: 18, blurIntensity: .light, opacityLevel: .content)
    }

    // MARK: - Hero Recording Section
    private var heroRecordingSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Pulsing glow effect when previewing
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isPreviewing ? 0.25 : 0.1),
                                Color.white.opacity(isPreviewing ? 0.1 : 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: isPreviewing ? 12 : 6)
                    .opacity(isPreviewing ? 1.0 : 0.7)
                    .scaleEffect(isPreviewing ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPreviewing
                    )
                
                // Main icon circle - larger and more prominent
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .liquidGlass(intensity: 0.85, cornerRadius: 70, blurIntensity: .medium, opacityLevel: .content)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
                
                Image(systemName: selectedIcon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white.opacity(0.95))
                    .scaleEffect(isPreviewing ? 1.05 : 1.0)
                    .animation(AppTheme.Animation.fluid, value: isPreviewing)
            }
            .onTapGesture {
                previewRecording()
            }
            
            // Duration as subtle caption
            if let duration = recording.duration, duration > 0 {
                Text(formatDuration(duration))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppColors.tertiaryText) // Phase 4: Vibrant color
            } else if let recordedAt = recording.recordedAt {
                Text(recordedAt, style: .relative)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.tertiaryText) // Phase 4: Vibrant color
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Sound Identity Section (Icon Selection)
    private var soundIdentitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dynamic label based on selected icon
            VStack(alignment: .leading, spacing: 4) {
                Text("Sound Identity")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryText) // Phase 4: Vibrant color
                
                Text(iconLabel(for: selectedIcon))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Carousel-style icon picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button(action: {
                            withAnimation(AppTheme.Animation.liquidSpring) {
                                selectedIcon = iconName
                            }
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }) {
                            // Phase 3: Use CircularIcon component for consistent design
                            CircularIcon(
                                icon: iconName,
                                color: .white, // Neutral color for icon picker
                                isActive: selectedIcon == iconName,
                                size: selectedIcon == iconName ? .primary : .secondary
                            )
                            .scaleEffect(selectedIcon == iconName ? 1.05 : 0.95)
                            .animation(AppTheme.Animation.liquidSpring, value: selectedIcon)
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
        }
    }
    
    // Helper to get emotional label for icon
    private func iconLabel(for iconName: String) -> String {
        switch iconName {
        case "waveform", "waveform.circle.fill":
            return "This sound feels like: Texture"
        case "music.note":
            return "This sound feels like: Music"
        case "cloud.rain.fill":
            return "This sound feels like: Rain"
        case "cloud.bolt.fill":
            return "This sound feels like: Thunder"
        case "tree.fill", "leaf.fill":
            return "This sound feels like: Nature"
        case "water.waves":
            return "This sound feels like: Water"
        case "flame.fill":
            return "This sound feels like: Fire"
        case "house.fill", "building.2.fill":
            return "This sound feels like: Indoor"
        case "bird.fill":
            return "This sound feels like: Wildlife"
        default:
            return "This sound feels like: Ambient"
        }
    }
    
    // MARK: - Metadata Form
    private var metadataForm: some View {
        VStack(spacing: 24) {
            // Title - neutral glass with blue only on focus
            VStack(alignment: .leading, spacing: 10) {
                Text("Title")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
                
                if isTitleEditing {
                    TextField("Name this soundscape", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                                .opacity(0.6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .onSubmit {
                            withAnimation(AppTheme.Animation.smooth) {
                                isTitleEditing = false
                                isTitleFocused = false
                            }
                        }
                        .onAppear {
                            isTitleFocused = true
                        }
                } else {
                    Button(action: {
                        withAnimation(AppTheme.Animation.smooth) {
                            isTitleEditing = true
                        }
                    }) {
                        HStack {
                            Text(title.isEmpty ? "Name this soundscape" : title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(title.isEmpty ? .white.opacity(0.5) : .white.opacity(0.95))
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                                .opacity(0.6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
            
            // Description - collapsed by default
            VStack(alignment: .leading, spacing: 10) {
                Button(action: {
                    withAnimation(AppTheme.Animation.smooth) {
                        isDescriptionExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Add a note")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
                        Spacer()
                        Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.tertiaryText) // Phase 4: Vibrant color
                    }
                }
                
                if isDescriptionExpanded {
                    TextField("Where was this recorded?", text: $description, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppColors.primaryText) // Phase 4: Vibrant color
                        .lineLimit(3...6)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .liquidGlass(intensity: 0.7, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    // MARK: - Action Buttons (Phase 1: Liquid Glass)
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Phase 1: Primary button with colored Liquid Glass
            PrimaryButton(
                "Save Changes",
                color: AppTheme.accent,
                isLoading: isSaving,
                isDisabled: false
            ) {
                handleSave()
            }
            .disabled(isSaving || isDeleting)
            
            // Remove Recording button - glass outline, neutral
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                    Text("Remove Recording")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .liquidGlass(intensity: 0.6, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
            }
            .disabled(isSaving || isDeleting)
        }
    }
    
    // MARK: - Actions
    private func handleSave() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title cannot be empty"
            showError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                guard let user = authManager.currentUser else {
                    await MainActor.run {
                        errorMessage = "You must be signed in to update recordings."
                        showError = true
                        isSaving = false
                    }
                    return
                }
                
                guard let accessToken = await authManager.getAccessToken() else {
                    await MainActor.run {
                        errorMessage = "Authentication required."
                        showError = true
                        isSaving = false
                    }
                    return
                }
                
                let videoPatch: UserRecordingVideoRPCPatch = {
                    guard pendingVideoRemoval else { return .leaveUnchanged }
                    guard let raw = recording.videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                          raw.lowercased().hasPrefix("http") else { return .leaveUnchanged }
                    let path = supabaseService.extractObjectPathFromPublicStorageURL(raw, bucket: "user-recording-videos")
                    return .clearVideo(removingStorageObjectPath: path)
                }()

                // Update recording in Supabase with retry on JWT expiration
                print("📝 Starting update for recording: \(recording.id)")
                NSLog("📝 UPDATE START: Recording ID: %@", recording.id.uuidString)
                
                do {
                    try await supabaseService.updateUserRecording(
                        accessToken: accessToken,
                        recordingId: recording.id,
                        name: title.trimmingCharacters(in: .whitespaces),
                        category: category,
                        description: description.isEmpty ? nil : description,
                        icon: selectedIcon,
                        videoPatch: videoPatch
                    )
                    print("✅ Update completed successfully")
                    NSLog("✅ UPDATE SUCCESS: Recording ID: %@", recording.id.uuidString)
                } catch SupabaseError.unauthorized {
                    // Token expired, refresh and retry
                    print("🔄 Token expired during update, refreshing...")
                    NSLog("🔄 UPDATE: Token expired, refreshing...")
                    try? await authManager.refreshTokenIfNeeded()
                    
                    guard let newToken = await authManager.getAccessToken() else {
                        throw SupabaseError.unauthorized
                    }
                    
                    try await supabaseService.updateUserRecording(
                        accessToken: newToken,
                        recordingId: recording.id,
                        name: title.trimmingCharacters(in: .whitespaces),
                        category: category,
                        description: description.isEmpty ? nil : description,
                        icon: selectedIcon,
                        videoPatch: videoPatch
                    )
                    print("✅ Update completed successfully after token refresh")
                    NSLog("✅ UPDATE SUCCESS: After token refresh, Recording ID: %@", recording.id.uuidString)
                } catch {
                    print("❌ Update failed with error: \(error)")
                    NSLog("❌ UPDATE FAILED: Recording ID: %@, Error: %@", recording.id.uuidString, error.localizedDescription)
                    throw error // Re-throw to be caught by outer catch
                }
                
                // Create updated AudioTrack
                var updatedTrack = AudioTrack(
                    id: recording.id,
                    name: title.trimmingCharacters(in: .whitespaces),
                    category: category,
                    icon: selectedIcon,
                    description: description.isEmpty ? nil : description,
                    audioUrl: recording.audioUrl,
                    videoUrl: pendingVideoRemoval ? nil : recording.videoUrl,
                    trackType: recording.trackType,
                    frequencyPreset: recording.frequencyPreset,
                    isActive: recording.isActive,
                    volume: recording.volume,
                    isUserRecording: recording.isUserRecording,
                    userId: recording.userId,
                    recordedAt: recording.recordedAt,
                    duration: recording.duration,
                    locationName: recording.locationName,
                    latitude: recording.latitude,
                    longitude: recording.longitude,
                    imageUrl: recording.imageUrl,
                    playCount: recording.playCount,
                    lastPlayedAt: recording.lastPlayedAt
                )
                updatedTrack.useAdvancedRendering = recording.useAdvancedRendering
                updatedTrack.spatialX = recording.spatialX
                updatedTrack.spatialY = recording.spatialY
                updatedTrack.reverbMix = recording.reverbMix
                updatedTrack.eqLowGain = recording.eqLowGain
                updatedTrack.eqMidGain = recording.eqMidGain
                updatedTrack.eqHighGain = recording.eqHighGain
                
                await MainActor.run {
                    if pendingVideoRemoval {
                        compositionSession.clearBackgroundIfRecordingMatches(recording.id)
                    }
                    isSaving = false
                    onSave(updatedTrack)
                    
                    // Post notification for recording update
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RecordingUpdated"),
                        object: nil,
                        userInfo: ["recordingId": updatedTrack.id.uuidString]
                    )
                    print("📢 Posted RecordingUpdated notification for: \(updatedTrack.name) (ID: \(updatedTrack.id.uuidString))")
                    
                    dismiss()
                }
            } catch {
                let errorDescription = error.localizedDescription
                print("❌ Error updating recording: \(error)")
                print("❌ Error description: \(errorDescription)")
                if let nsError = error as NSError? {
                    print("❌ Error domain: \(nsError.domain)")
                    print("❌ Error code: \(nsError.code)")
                    print("❌ Error userInfo: \(nsError.userInfo)")
                }
                
                await MainActor.run {
                    errorMessage = "Failed to update recording: \(errorDescription)"
                    showError = true
                    isSaving = false
                }
            }
        }
    }
    
    private func handleDelete() {
        isDeleting = true
        
        Task {
            do {
                // Get access token with retry on expiration
                var accessToken = await authManager.getAccessToken()
                
                // Try to refresh token if needed
                if accessToken == nil {
                    try? await authManager.refreshTokenIfNeeded()
                    accessToken = await authManager.getAccessToken()
                }
                
                guard let token = accessToken else {
                    await MainActor.run {
                        errorMessage = "Authentication required."
                        showError = true
                        isDeleting = false
                    }
                    return
                }

                guard let ownerUserId = await MainActor.run(body: { recording.userId ?? authManager.currentUser?.id }) else {
                    await MainActor.run {
                        errorMessage = "You must be signed in to delete recordings."
                        showError = true
                        isDeleting = false
                    }
                    return
                }
                
                // Delete from Supabase with retry on JWT expiration
                // Note: deleteUserRecording now treats "Recording not found" as success (idempotent)
                print("🗑️ Starting delete for recording: \(recording.id)")
                NSLog("🗑️ DELETE START: Recording ID: %@", recording.id.uuidString)
                
                do {
                    try await supabaseService.deleteUserRecording(
                        accessToken: token,
                        recordingId: recording.id,
                        userId: ownerUserId
                    )
                    print("✅ Delete completed successfully")
                    NSLog("✅ DELETE SUCCESS: Recording ID: %@", recording.id.uuidString)
                } catch SupabaseError.unauthorized {
                    // Token expired, refresh and retry
                    print("🔄 Token expired during delete, refreshing...")
                    NSLog("🔄 DELETE: Token expired, refreshing...")
                    try? await authManager.refreshTokenIfNeeded()
                    
                    guard let newToken = await authManager.getAccessToken() else {
                        throw SupabaseError.unauthorized
                    }
                    
                    try await supabaseService.deleteUserRecording(
                        accessToken: newToken,
                        recordingId: recording.id,
                        userId: ownerUserId
                    )
                    print("✅ Delete completed successfully after token refresh")
                    NSLog("✅ DELETE SUCCESS: After token refresh, Recording ID: %@", recording.id.uuidString)
                } catch {
                    // Even if delete fails (e.g., recording doesn't exist in DB),
                    // we still want to remove it from local state since the goal is achieved
                    print("⚠️ Delete returned error, but removing from local state anyway: \(error.localizedDescription)")
                    NSLog("⚠️ DELETE ERROR (continuing anyway): Recording ID: %@, Error: %@", recording.id.uuidString, error.localizedDescription)
                }
                
                // Always remove from local state, even if database delete had issues
                // This handles the case where recording exists locally but not in database
                await MainActor.run {
                    isDeleting = false
                    onDelete() // This will remove from local state and refresh
                    
                    // Post notification for recording deletion
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RecordingDeleted"),
                        object: nil,
                        userInfo: ["recordingId": recording.id.uuidString]
                    )
                    print("📢 Posted RecordingDeleted notification for: \(recording.name) (ID: \(recording.id.uuidString))")
                    
                    dismiss()
                }
            } catch {
                let errorDescription = error.localizedDescription
                print("❌ Error deleting recording: \(error)")
                print("❌ Error description: \(errorDescription)")
                if let nsError = error as NSError? {
                    print("❌ Error domain: \(nsError.domain)")
                    print("❌ Error code: \(nsError.code)")
                    print("❌ Error userInfo: \(nsError.userInfo)")
                }
                
                await MainActor.run {
                    errorMessage = "Failed to delete recording: \(errorDescription)"
                    showError = true
                    isDeleting = false
                }
            }
        }
    }
    
    // MARK: - Preview Functionality
    private func previewRecording() {
        // Light haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Stop any existing preview
        previewPlayer?.pause()
        previewPlayer = nil
        isPreviewing = false
        
        // Start preview (short loop, 3-5 seconds)
        guard let url = URL(string: recording.audioUrl) else { return }
        
        let player = AVPlayer(url: url)
        previewPlayer = player
        
        // Set volume lower for preview
        player.volume = 0.5
        
        // Play for 3-5 seconds then stop
        isPreviewing = true
        player.play()
        
        // Auto-stop after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if self.previewPlayer === player {
                player.pause()
                self.isPreviewing = false
                self.previewPlayer = nil
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d hr, %d min", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d min, %d sec", minutes, seconds)
        } else {
            return String(format: "%d sec", seconds)
        }
    }
}

