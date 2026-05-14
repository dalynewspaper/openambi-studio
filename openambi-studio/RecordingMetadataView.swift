import SwiftUI
import AVFoundation
import AVKit
import CoreLocation

struct RecordingMetadataView: View {
    let recordingResult: RecordingResult
    let onSave: (AudioTrack) -> Void
    let onCancel: () -> Void
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var supabaseService = SupabaseService()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var compositionSession: CompositionSessionStore
    
    private let localStorage = LocalRecordingStorage.shared
    private let videoAssetStore = VideoAssetStore.shared
    
    @State private var title: String = ""
    @State private var category: String = "My Recordings"
    @State private var description: String = ""
    @State private var selectedIcon: String = "waveform"
    @State private var showLocationPermissionAlert = false
    @State private var isUploading = false
    @State private var isSavingToLibrary = false // Shows after upload, while waiting for DB replication
    @State private var saveStatusMessage = "Uploading recording..." // Dynamic status message
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAuthentication = false
    @State private var showLocationSettingsAlert = false
    @State private var useVideoBackground = true
    @State private var videoThumbnail: UIImage?
    
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
        "heart.fill", "moon.fill", "sun.max.fill"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - consistent with app theme
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Recording info display
                        recordingInfoSection
                        
                        // Video preview (if video attached)
                        if recordingResult.videoURL != nil {
                            videoPreviewSection
                        }
                        
                        // Icon selection
                        iconSelectionSection
                        
                        // Metadata form
                        metadataForm
                        
                        // Location section
                        locationSection
                        
                        // Save button
                        saveButton
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    // Dismiss keyboard when tapping outside text fields
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("Save Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            generateAutoTitle()
            permissionsManager.updatePermissionStates()
            requestLocationIfNeeded()
            generateVideoThumbnail()
        }
        .alert("Location Access", isPresented: $showLocationPermissionAlert) {
            Button("Settings") {
                PermissionsManager.shared.openLocationSettings()
            }
            Button("Skip", role: .cancel) {}
        } message: {
            Text("We'd like to tag your recordings with location so you can easily find and organize them later. For example, \"Beach Waves - Malibu\" or \"Coffee Shop - Downtown\".\n\nYour location is only captured when you record and is stored privately with your recordings.")
        }
        .alert("Location Permission Required", isPresented: $showLocationSettingsAlert) {
            Button("Settings") {
                PermissionsManager.shared.openLocationSettings()
            }
            Button("Skip", role: .cancel) {}
        } message: {
            Text("Location access is currently denied. You can enable it in Settings to tag your recordings with location.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showAuthentication) {
            AuthenticationView(authManager: authManager)
                .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                    // After successful authentication, dismiss sheet and save
                    if isAuthenticated && !authManager.isLoading {
                        showAuthentication = false
                        // Small delay to ensure auth state is fully updated
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            handleSave()
                        }
                    }
                }
        }
        .overlay {
            if isUploading || isSavingToLibrary {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Animated progress indicator
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        // Status message
                        VStack(spacing: 8) {
                            Text(saveStatusMessage)
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .semibold))
                                .multilineTextAlignment(.center)
                            
                            if isSavingToLibrary {
                                Text("This may take a few seconds...")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 14, weight: .regular))
                            }
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 40)
                }
            }
        }
    }
    
    // MARK: - Recording Info Section
    private var recordingInfoSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Recording icon
                CircularIcon(
                    icon: "waveform.circle.fill",
                    color: SoundColor.fireplace,
                    isActive: true,
                    size: .primary
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatDuration(recordingResult.duration))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(formatFileSize(recordingResult.fileSize))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
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
                    }
            )
        }
    }
    
    // MARK: - Icon Selection Section
    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            HapticFeedback.light()
                        }) {
                            CircularIcon(
                                icon: icon,
                                color: SoundColor.rain,
                                isActive: selectedIcon == icon,
                                size: selectedIcon == icon ? .primary : .secondary
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
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
                
                TextField("Enter title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .submitLabel(.done)
                    .onSubmit {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Menu {
                    ForEach(categories, id: \.self) { cat in
                        Button(cat) {
                            category = cat
                        }
                    }
                } label: {
                    HStack {
                        Text(category)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 12))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("Add notes about this recording...", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .submitLabel(.done)
                    .onSubmit {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            }
        }
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.white.opacity(0.8))
                Text("Location")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if let location = locationManager.currentLocation {
                VStack(alignment: .leading, spacing: 5) {
                    if let locationName = locationManager.locationName {
                        Text(locationName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            } else {
                Button(action: {
                    let status = permissionsManager.checkLocationPermission()
                    switch status {
                    case .denied, .restricted:
                        showLocationSettingsAlert = true
                    case .notDetermined:
                        Task {
                            let granted = await permissionsManager.requestLocationPermission()
                            if granted {
                                locationManager.requestLocation()
                            }
                        }
                    case .authorizedWhenInUse, .authorizedAlways:
                        locationManager.requestLocation()
                    @unknown default:
                        break
                    }
                }) {
                    HStack {
                        Image(systemName: "location.slash")
                            .foregroundColor(.white.opacity(0.6))
                        Text("Add location")
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
    }
    
    // MARK: - Video Preview Section
    private var videoPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "film.fill")
                    .foregroundColor(.white.opacity(0.8))
                Text("Video Background")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(spacing: 16) {
                // Thumbnail preview
                if let thumbnail = videoThumbnail {
                    ZStack {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Play overlay icon
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                                    .offset(x: 2)
                            }
                        
                        // Duration badge
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(recordingResult.duration))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(.black.opacity(0.6))
                                    )
                                    .padding(10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    // Placeholder while generating thumbnail
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 180)
                        .overlay {
                            ProgressView()
                                .tint(.white.opacity(0.5))
                        }
                }
                
                // Toggle for using video as background
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use as ambient background")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Loop the video behind your soundscape")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useVideoBackground)
                        .labelsHidden()
                        .tint(SoundColor.rain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
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
                    }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonBackgroundStyle: AnyShapeStyle {
        if title.isEmpty {
            AnyShapeStyle(Color.white.opacity(0.2))
        } else {
            AnyShapeStyle(SoundColor.rainGradient)
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: handleSave) {
            Text("Save Recording")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(buttonBackgroundStyle)
                )
        }
        .disabled(title.isEmpty)
        .padding(.top, 10)
    }
    
    // MARK: - Actions
    
    private func generateAutoTitle() {
        if title.isEmpty {
            if let locationName = locationManager.locationName {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                title = "\(locationName) - \(formatter.string(from: Date()))"
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                title = "Recording - \(formatter.string(from: Date()))"
            }
        }
    }
    
    private func generateVideoThumbnail() {
        guard let videoURL = recordingResult.videoURL else { return }
        
        Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 640, height: 360)
            
            do {
                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                await MainActor.run {
                    self.videoThumbnail = uiImage
                }
            } catch {
                print("⚠️ Failed to generate video thumbnail: \(error.localizedDescription)")
            }
        }
    }
    
    private func requestLocationIfNeeded() {
        let status = permissionsManager.checkLocationPermission()
        switch status {
        case .notDetermined:
            // Request permission
            Task {
                let granted = await permissionsManager.requestLocationPermission()
                if granted {
                    locationManager.requestLocation()
                }
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted, request location
            locationManager.requestLocation()
        case .denied, .restricted:
            // Permission denied - show alert if user tries to add location
            break
        @unknown default:
            break
        }
    }
    
    private func handleSave() {
        guard !title.isEmpty else { return }

        let recordingId = UUID()
        
        isUploading = true
        
        Task {
            // If not signed in, save locally only
            guard let user = authManager.currentUser else {
                await handleLocalOnlySave(recordingId: recordingId)
                return
            }
            
            guard var accessToken = await authManager.getAccessToken() else {
                // No token, but user is signed in - save locally as fallback
                await handleLocalOnlySave(recordingId: recordingId)
                return
            }
            
            let persistedVideoURL = persistVideoIfNeeded(recordingId: recordingId)
            do {
                // Try upload with current token
                var track = try await supabaseService.uploadRecording(
                    recordingId: recordingId,
                    fileURL: recordingResult.fileURL,
                    accessToken: accessToken,
                    userId: user.id,
                    title: title,
                    category: category,
                    description: description.isEmpty ? nil : description,
                    icon: selectedIcon,
                    duration: recordingResult.duration,
                    fileSize: recordingResult.fileSize,
                    locationName: locationManager.locationName,
                    latitude: locationManager.currentLocation?.coordinate.latitude,
                    longitude: locationManager.currentLocation?.coordinate.longitude,
                    videoFileURL: persistedVideoURL
                )

                
                // Upload complete, now verify it appears in database (handles read replica lag)
                await MainActor.run {
                    isUploading = false
                    isSavingToLibrary = true
                    saveStatusMessage = "Saving to your library..."
                }
                
                // Wait for recording to appear in database with retry logic
                await verifyRecordingInDatabase(
                    recordingId: track.id,
                    userId: user.id,
                    accessToken: accessToken,
                    track: track
                )
            } catch let error as SupabaseError {
                // If we get a 403 (forbidden) or 401 (unauthorized), try refreshing the token
                switch error {
                case .forbidden, .unauthorized:
                    print("🔄 Token expired, attempting to refresh...")
                    if let refreshedToken = try? await authManager.refreshTokenIfNeeded() {
                        print("✅ Token refreshed, retrying upload...")
                        accessToken = refreshedToken
                        
                        // Retry upload with refreshed token
                        do {
                            var track = try await supabaseService.uploadRecording(
                                recordingId: recordingId,
                                fileURL: recordingResult.fileURL,
                                accessToken: accessToken,
                                userId: user.id,
                                title: title,
                                category: category,
                                description: description.isEmpty ? nil : description,
                                icon: selectedIcon,
                                duration: recordingResult.duration,
                                fileSize: recordingResult.fileSize,
                                locationName: locationManager.locationName,
                                latitude: locationManager.currentLocation?.coordinate.latitude,
                                longitude: locationManager.currentLocation?.coordinate.longitude,
                                videoFileURL: persistedVideoURL
                            )

                            
                            // Upload complete, now verify it appears in database
                            await MainActor.run {
                                isUploading = false
                                isSavingToLibrary = true
                                saveStatusMessage = "Saving to your library..."
                            }
                            
                            // Wait for recording to appear in database with retry logic
                            await verifyRecordingInDatabase(
                                recordingId: track.id,
                                userId: user.id,
                                accessToken: accessToken,
                                track: track
                            )
                        } catch {
                            // Retry also failed - save locally
                            await handleCloudUploadFailure(error: error, recordingId: recordingId)
                        }
                    } else {
                        // Token refresh failed - save locally if we can
                        await handleCloudUploadFailure(error: NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."]), recordingId: recordingId)
                    }
                default:
                    // Network or other error - save locally as fallback
                    await handleCloudUploadFailure(error: error, recordingId: recordingId)
                }
            } catch {
                // Network or other error - save locally as fallback
                await handleCloudUploadFailure(error: error, recordingId: recordingId)
            }
        }
    }
    
    // MARK: - Handle Local Only Save
    /// Saves recording locally when user is not signed in
    private func handleLocalOnlySave(recordingId: UUID) async {
        print("💾 Saving recording locally (user not signed in)")
        
        do {
            // Save to local storage
            try localStorage.saveRecording(
                fileURL: recordingResult.fileURL,
                id: recordingId,
                title: title,
                category: category,
                description: description.isEmpty ? nil : description,
                icon: selectedIcon,
                duration: recordingResult.duration,
                fileSize: recordingResult.fileSize,
                videoURL: useVideoBackground ? recordingResult.videoURL : nil,
                locationName: locationManager.locationName,
                latitude: locationManager.currentLocation?.coordinate.latitude,
                longitude: locationManager.currentLocation?.coordinate.longitude
            )
            
            // Convert to AudioTrack for immediate use
            if let localMetadata = localStorage.loadLocalRecordings().first(where: { $0.id == recordingId }),
               let track = localStorage.toAudioTrack(localMetadata) {
                await MainActor.run {
                    isUploading = false
                    saveStatusMessage = "Saved locally (sign in to sync to cloud)"
                    
                    // Show success message briefly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Post notification for sync
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RecordingSavedLocally"),
                            object: nil,
                            userInfo: ["recordingId": recordingId.uuidString]
                        )
                        applyMixBackgroundPreference(for: track)
                        onSave(track)
                    }
                }
            } else {
                throw NSError(domain: "LocalStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create track from local storage"])
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = "Failed to save recording locally: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Handle Cloud Upload Failure
    /// Saves recording locally when cloud upload fails
    private func handleCloudUploadFailure(error: Error, recordingId: UUID) async {
        print("⚠️ Cloud upload failed, saving locally: \(error.localizedDescription)")
        
        do {
            // Save to local storage
            try localStorage.saveRecording(
                fileURL: recordingResult.fileURL,
                id: recordingId,
                title: title,
                category: category,
                description: description.isEmpty ? nil : description,
                icon: selectedIcon,
                duration: recordingResult.duration,
                fileSize: recordingResult.fileSize,
                videoURL: useVideoBackground ? recordingResult.videoURL : nil,
                locationName: locationManager.locationName,
                latitude: locationManager.currentLocation?.coordinate.latitude,
                longitude: locationManager.currentLocation?.coordinate.longitude
            )
            
            // Convert to AudioTrack for immediate use
            if let localMetadata = localStorage.loadLocalRecordings().first(where: { $0.id == recordingId }),
               let track = localStorage.toAudioTrack(localMetadata) {
                await MainActor.run {
                    isUploading = false
                    saveStatusMessage = "Saved locally (will sync when online)"
                    
                    // Show success message briefly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Post notification for sync
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RecordingSavedLocally"),
                            object: nil,
                            userInfo: ["recordingId": recordingId.uuidString]
                        )
                        applyMixBackgroundPreference(for: track)
                        onSave(track)
                    }
                }
            } else {
                throw NSError(domain: "LocalStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create track from local storage"])
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = "Failed to save recording. Cloud upload failed: \(error.localizedDescription). Local save also failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func applyMixBackgroundPreference(for track: AudioTrack) {
        guard useVideoBackground,
              let v = track.videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty else { return }
        compositionSession.setBackgroundRecording(id: track.id)
    }

    private func persistVideoIfNeeded(recordingId: UUID) -> URL? {
        guard useVideoBackground, let videoURL = recordingResult.videoURL else { return nil }

        do {
            let savedURL = try videoAssetStore.saveVideoAsset(sourceURL: videoURL, id: recordingId)
            return savedURL
        } catch {
            print("⚠️ Failed to persist video asset: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Verify Recording in Database
    /// Waits for the recording to appear in the database (handles read replica lag)
    private func verifyRecordingInDatabase(
        recordingId: UUID,
        userId: UUID,
        accessToken: String,
        track: AudioTrack
    ) async {
        var found = false
        let maxAttempts = 10
        let initialDelay: TimeInterval = 1.0 // Start after 1 second (DB insert already waited 2s)
        
        // Wait initial delay before first attempt
        try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
        
        for attempt in 1...maxAttempts {
            // Update status message
            await MainActor.run {
                if attempt == 1 {
                    saveStatusMessage = "Verifying in library..."
                } else {
                    saveStatusMessage = "Verifying in library... (\(attempt)/\(maxAttempts))"
                }
            }
            
            do {
                // Try targeted fetch first (more efficient)
                // Bypass cache to ensure we get the latest data for verification
                let recordings = try await supabaseService.fetchUserRecordings(
                    accessToken: accessToken,
                    userId: userId,
                    recordingId: recordingId,
                    bypassCache: true
                )
                
                if recordings.contains(where: { $0.id == recordingId }) {
                    print("✅ Recording verified in database on attempt \(attempt)")
                    found = true
                    break
                }
            } catch {
                print("⚠️ Verification attempt \(attempt) failed: \(error)")
            }
            
            // Wait before next attempt (except on last attempt)
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(0.8 * 1_000_000_000)) // 0.8s between attempts
            }
        }
        
        await MainActor.run {
            if found {
                saveStatusMessage = "Saved!"
                // Brief success message before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Clear loading state
                    isSavingToLibrary = false
                    // Post notification for other views to refresh
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RecordingSaved"),
                        object: nil,
                        userInfo: ["recordingId": track.id.uuidString]
                    )
                    print("📢 Posted RecordingSaved notification for: \(track.name) (ID: \(track.id.uuidString))")
                    applyMixBackgroundPreference(for: track)
                    onSave(track)
                }
            } else {
                // Even if not found, proceed (might be a false negative due to lag)
                print("⚠️ Recording not verified after \(maxAttempts) attempts, but proceeding anyway")
                saveStatusMessage = "Saved!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Clear loading state
                    isSavingToLibrary = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RecordingSaved"),
                        object: nil,
                        userInfo: ["recordingId": track.id.uuidString]
                    )
                    print("📢 Posted RecordingSaved notification for: \(track.name) (ID: \(track.id.uuidString))")
                    applyMixBackgroundPreference(for: track)
                    onSave(track)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}


// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var locationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentLocation = location
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                // Try to get a meaningful location name
                if let name = placemark.name {
                    self.locationName = name
                } else if let locality = placemark.locality {
                    self.locationName = locality
                } else if let administrativeArea = placemark.administrativeArea {
                    self.locationName = administrativeArea
                }
            }
        }
    }
}

#Preview {
    RecordingMetadataView(
        recordingResult: RecordingResult(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            videoURL: nil,
            duration: 125.5,
            fileSize: 1200000,
            averageLevel: 0.5,
            peakLevel: 0.8
        ),
        onSave: { _ in },
        onCancel: {}
    )
    .environmentObject(AuthManager())
    .environmentObject(CompositionSessionStore())
}

