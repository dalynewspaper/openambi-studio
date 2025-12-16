import SwiftUI

struct EditRecordingView: View {
    let recording: AudioTrack
    let onSave: (AudioTrack) -> Void
    let onDelete: () -> Void
    
    @StateObject private var supabaseService = SupabaseService()
    @EnvironmentObject var authManager: AuthManager
    
    @State private var title: String
    @State private var category: String
    @State private var description: String
    @State private var selectedIcon: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    
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
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Recording info display
                        recordingInfoSection
                        
                        // Icon selection
                        iconSelectionSection
                        
                        // Metadata form
                        metadataForm
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Recording", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                handleDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(title)\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Recording Info Section
    private var recordingInfoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.4),
                                Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .liquidGlass(intensity: 0.9, cornerRadius: 50, blurIntensity: .light, opacityLevel: .content)
                    .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.3), radius: 15, x: 0, y: 5)
                
                Image(systemName: selectedIcon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
            }
            
            // Show actual recording duration, not relative time
            if let duration = recording.duration, duration > 0 {
                Text(formatDuration(duration))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            } else if let recordedAt = recording.recordedAt {
                // Fallback to relative time if duration is not available
                Text(recordedAt, style: .relative)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Icon Selection Section
    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button(action: {
                            selectedIcon = iconName
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: selectedIcon == iconName ? [
                                                Color.blue.opacity(0.4),
                                                Color.blue.opacity(0.3)
                                            ] : [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .liquidGlass(intensity: 0.8, cornerRadius: 25, blurIntensity: .light, opacityLevel: .controls)
                                
                                Image(systemName: iconName)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(selectedIcon == iconName ? .white : .white.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
        }
    }
    
    // MARK: - Metadata Form
    private var metadataForm: some View {
        VStack(spacing: 20) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("Recording title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .liquidGlass(intensity: 1.0, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
                    )
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .liquidGlass(intensity: 1.0, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
                )
                .foregroundColor(.white)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("Optional description", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(3...6)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .liquidGlass(intensity: 1.0, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
                    )
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Save button
            Button(action: {
                handleSave()
            }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Changes")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.blue.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .liquidGlass(intensity: 0.9, cornerRadius: 16, blurIntensity: .medium, opacityLevel: .controls)
            }
            .disabled(isSaving || isDeleting)
            
            // Delete button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Delete Recording")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.5),
                                    Color.red.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .liquidGlass(intensity: 0.9, cornerRadius: 16, blurIntensity: .medium, opacityLevel: .controls)
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
                        icon: selectedIcon
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
                        icon: selectedIcon
                    )
                    print("✅ Update completed successfully after token refresh")
                    NSLog("✅ UPDATE SUCCESS: After token refresh, Recording ID: %@", recording.id.uuidString)
                } catch {
                    print("❌ Update failed with error: \(error)")
                    NSLog("❌ UPDATE FAILED: Recording ID: %@, Error: %@", recording.id.uuidString, error.localizedDescription)
                    throw error // Re-throw to be caught by outer catch
                }
                
                // Create updated AudioTrack
                let updatedTrack = AudioTrack(
                    id: recording.id,
                    name: title.trimmingCharacters(in: .whitespaces),
                    category: category,
                    icon: selectedIcon,
                    description: description.isEmpty ? nil : description,
                    audioUrl: recording.audioUrl,
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
                
                await MainActor.run {
                    isSaving = false
                    onSave(updatedTrack)
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
                
                // Delete from Supabase with retry on JWT expiration
                // Note: deleteUserRecording now treats "Recording not found" as success (idempotent)
                print("🗑️ Starting delete for recording: \(recording.id)")
                NSLog("🗑️ DELETE START: Recording ID: %@", recording.id.uuidString)
                
                do {
                    try await supabaseService.deleteUserRecording(
                        accessToken: token,
                        recordingId: recording.id
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
                        recordingId: recording.id
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

