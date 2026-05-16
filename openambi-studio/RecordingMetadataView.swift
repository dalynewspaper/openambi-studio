import SwiftUI
import AVFoundation
import CoreLocation

struct RecordingMetadataView: View {
    let recordingResult: RecordingResult
    let onSave: (AudioTrack) -> Void
    let onCancel: () -> Void
    
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var supabaseService = SupabaseService()
    @EnvironmentObject var authManager: AuthManager
    
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
                        
                        // Location section
                        locationSection
                        
                        // Save button
                        saveButton
                    }
                    .padding(20)
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
            requestLocationIfNeeded()
        }
        .alert("Location Permission", isPresented: $showLocationPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Skip", role: .cancel) {}
        } message: {
            Text("Enable location access to automatically tag your recordings with where they were made.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showAuthentication) {
            AuthenticationView(authManager: authManager)
            .onDisappear {
                // After authentication, try saving again if user signed in
                if authManager.isAuthenticated {
                    // Small delay to ensure auth state is updated
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

                    AuroraLoader.Modal(
                        title: saveStatusMessage,
                        subtitle: isSavingToLibrary
                            ? "This may take a few seconds…"
                            : nil
                    )
                }
            }
        }
    }
    
    // MARK: - Recording Info Section
    private var recordingInfoSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Recording icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.3),
                                    Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.3, blue: 0.3),
                                    Color(red: 1.0, green: 0.5, blue: 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
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
                        }) {
                            ZStack {
                                Circle()
                                    .fill(selectedIcon == icon ? 
                                          LinearGradient(
                                            colors: [
                                                Color(red: 0.3, green: 0.5, blue: 1.0),
                                                Color(red: 0.5, green: 0.3, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          ) :
                                          LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(selectedIcon == icon ? .white : .white.opacity(0.7))
                            }
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
                    if locationManager.authorizationStatus == .denied {
                        showLocationPermissionAlert = true
                    } else {
                        locationManager.requestLocation()
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
    
    // MARK: - Computed Properties
    
    private var buttonBackgroundStyle: AnyShapeStyle {
        if title.isEmpty {
            AnyShapeStyle(Color.white.opacity(0.2))
        } else {
            AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.72, blue: 1.0),
                    Color(red: 0.18, green: 0.6, blue: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ))
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
    
    private func requestLocationIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestLocation()
        }
    }
    
    private func handleSave() {
        guard !title.isEmpty else { return }
        
        // If not signed in, show authentication sheet instead of error
        guard let user = authManager.currentUser else {
            showAuthentication = true
            return
        }
        
        isUploading = true
        
        Task {
            guard var accessToken = await authManager.getAccessToken() else {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "You must be signed in to save recordings."
                    showError = true
                }
                return
            }
            
            do {
                // Try upload with current token
                let track = try await supabaseService.uploadRecording(
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
                    longitude: locationManager.currentLocation?.coordinate.longitude
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
                            let track = try await supabaseService.uploadRecording(
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
                                longitude: locationManager.currentLocation?.coordinate.longitude
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
                            await MainActor.run {
                                isUploading = false
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    } else {
                        // Token refresh failed
                        await MainActor.run {
                            isUploading = false
                            errorMessage = "Authentication expired. Please sign in again."
                            showError = true
                        }
                    }
                default:
                    // Other error
                    await MainActor.run {
                        isUploading = false
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
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
                let recordings = try await supabaseService.fetchUserRecordings(
                    accessToken: accessToken,
                    userId: userId,
                    recordingId: recordingId
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
            duration: 125.5,
            fileSize: 1200000,
            averageLevel: 0.5,
            peakLevel: 0.8
        ),
        onSave: { _ in },
        onCancel: {}
    )
}

