import SwiftUI

struct UserRecordingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var supabaseService = SupabaseService()
    
    @State private var recordings: [AudioTrack] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedRecording: AudioTrack? = nil
    @State private var showClearCacheAlert = false
    @State private var shouldSkipNextLoad = false // Flag to prevent reload after clearing cache
    // Track local state that hasn't been persisted to database yet
    @State private var locallyDeletedIds: Set<UUID> = []
    @State private var locallyUpdatedRecordings: [UUID: AudioTrack] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Edge-to-edge background with gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else if recordings.isEmpty {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .liquidGlass(intensity: 0.8, cornerRadius: 60, blurIntensity: .light, opacityLevel: .content)
                            
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Text("No Recordings")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Recordings you save will appear here")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(recordings) { recording in
                                RecordingRow(
                                    recording: recording,
                                    onDelete: {
                                        // This shouldn't normally be called since deletion happens in EditRecordingView
                                        // But if it is, use smart refresh to preserve state
                                        Task { @MainActor in
                                            await smartRefresh()
                                        }
                                    },
                                    onEdit: {
                                        selectedRecording = recording
                                    }
                                )
                                .environmentObject(audioManager)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("My Recordings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            print("🔄 Manual refresh triggered")
                            Task { @MainActor in
                                await smartRefresh()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .disabled(isLoading)
                        
                        if !recordings.isEmpty {
                            Button(action: {
                                showClearCacheAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .onAppear {
            // Skip load if we just cleared cache (to prevent immediate reload)
            if shouldSkipNextLoad {
                shouldSkipNextLoad = false
                return
            }
            loadRecordings()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingSaved"))) { notification in
            // Refresh when a new recording is saved
            // With RLS fix, recordings appear immediately, so just a simple refresh is needed
            print("🔄 Received RecordingSaved notification - refreshing recordings list")
            
            Task { @MainActor in
                // Small delay to allow database commit (insert already waited 2s, but add 0.5s buffer)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await smartRefresh()
            }
        }
        .refreshable {
            await smartRefresh()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllCachedRecordings()
            }
        } message: {
            Text("This will remove all cached recordings from the app. The recordings will still be in the database, but you'll need to reload them.")
        }
        .sheet(item: $selectedRecording) { recording in
            EditRecordingView(
                recording: recording,
                onSave: { updatedTrack in
                    // Update in local list immediately for instant UI feedback
                    if let index = recordings.firstIndex(where: { $0.id == updatedTrack.id }) {
                        recordings[index] = updatedTrack
                    }
                    // Track this as a local update
                    locallyUpdatedRecordings[updatedTrack.id] = updatedTrack
                    // Update in audioManager if it's loaded
                    if let index = audioManager.tracks.firstIndex(where: { $0.id == updatedTrack.id }) {
                        audioManager.tracks[index] = updatedTrack
                    } else {
                        // Add to audioManager if not already there
                        audioManager.loadTracks(audioManager.tracks + [updatedTrack])
                    }
                    // Reload from database after a delay, but preserve local updates if DB hasn't updated yet
                    Task { @MainActor in
                        // Longer delay to allow for database replication/consistency
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                        // Only refresh if the database actually has the updated data
                        // Otherwise keep the local state (which is correct)
                        await refreshRecordingsPreservingLocalUpdates(updatedTrackId: updatedTrack.id)
                    }
                },
                onDelete: {
                    // Remove from local recordings list immediately for instant UI feedback
                    recordings.removeAll { $0.id == recording.id }
                    
                    // Track this as locally deleted
                    locallyDeletedIds.insert(recording.id)
                    // Remove from local updates if it was there
                    locallyUpdatedRecordings.removeValue(forKey: recording.id)
                    
                    // Remove from AudioManager using the proper method
                    audioManager.removeTrack(recording.id)
                    
                    // Clear cache for this specific recording
                    do {
                        try AudioCacheService.shared.removeCachedFile(recording.audioUrl)
                        print("🗑️ Cleared cache for recording: \(recording.audioUrl)")
                    } catch {
                        print("⚠️ Failed to clear cache for recording: \(error.localizedDescription)")
                    }
                    
                    // Refresh list from database after a delay, but keep it removed locally
                    Task { @MainActor in
                        // Longer delay to allow for database replication/consistency
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                        // Refresh, but ensure deleted recording stays removed
                        await refreshRecordingsPreservingDeletions(deletedRecordingId: recording.id)
                    }
                }
            )
            .environmentObject(authManager)
        }
    }
    
    private func loadRecordings() {
        guard let user = authManager.currentUser else {
            errorMessage = "You must be signed in to view recordings."
            showError = true
            isLoading = false
            return
        }
        
        isLoading = true
        
        Task {
            do {
                guard let accessToken = await authManager.getAccessToken() else {
                    await MainActor.run {
                        errorMessage = "Authentication required."
                        showError = true
                        isLoading = false
                    }
                    return
                }
                
                print("🔍 Loading user recordings for user: \(user.id)")
                let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                    accessToken: accessToken,
                    userId: user.id
                )
                
                print("✅ Fetched \(fetchedRecordings.count) recordings")
                print("📋 Recording IDs: \(fetchedRecordings.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" }.joined(separator: ", "))")
                
                await MainActor.run {
                    recordings = fetchedRecordings
                    isLoading = false
                }
            } catch {
                print("❌ Error loading recordings: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load recordings: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    @MainActor
    private func refreshRecordings() async {
        guard let user = authManager.currentUser else {
            return
        }
        
        do {
            guard let accessToken = await authManager.getAccessToken() else {
                return
            }
            
            print("🔄 Refreshing recordings list...")
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id
            )
            
            recordings = fetchedRecordings
            print("🔄 Refreshed: \(fetchedRecordings.count) recordings")
            print("📋 Recording IDs after refresh: \(fetchedRecordings.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" }.joined(separator: ", "))")
        } catch {
            print("❌ Error refreshing recordings: \(error)")
        }
    }
    
    /// Refresh recordings but preserve local updates if database hasn't updated yet
    @MainActor
    private func refreshRecordingsPreservingLocalUpdates(updatedTrackId: UUID) async {
        guard let user = authManager.currentUser else {
            return
        }
        
        do {
            guard let accessToken = await authManager.getAccessToken() else {
                return
            }
            
            print("🔄 Refreshing recordings (preserving local updates)...")
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id
            )
            
            // Check if the updated recording is in the fetched list
            if let fetchedTrack = fetchedRecordings.first(where: { $0.id == updatedTrackId }) {
                // Database has the recording - check if it's actually updated
                if let localTrack = locallyUpdatedRecordings[updatedTrackId] ?? recordings.first(where: { $0.id == updatedTrackId }) {
                    // Compare: if local has newer data (different name/updated_at), keep local
                    if localTrack.name != fetchedTrack.name || 
                       localTrack.category != fetchedTrack.category ||
                       localTrack.description != fetchedTrack.description ||
                       localTrack.icon != fetchedTrack.icon {
                        print("⚠️ Database still has old data for \(updatedTrackId), keeping local update")
                        // Keep local version, merge with fetched (for other recordings)
                        var merged = fetchedRecordings.filter { $0.id != updatedTrackId && !locallyDeletedIds.contains($0.id) }
                        merged.append(localTrack)
                        recordings = merged.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
                        return
                    } else {
                        // Database is up to date, remove from local updates
                        locallyUpdatedRecordings.removeValue(forKey: updatedTrackId)
                    }
                }
            }
            
            // Apply smart merge: filter deleted, preserve local updates
            let filtered = fetchedRecordings.filter { !locallyDeletedIds.contains($0.id) }
            var merged = filtered
            for (id, localTrack) in locallyUpdatedRecordings {
                if let index = merged.firstIndex(where: { $0.id == id }) {
                    merged[index] = localTrack
                } else {
                    merged.append(localTrack)
                }
            }
            recordings = merged.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
            print("🔄 Refreshed: \(merged.count) recordings (database was up to date)")
        } catch {
            print("❌ Error refreshing recordings: \(error)")
        }
    }
    
    /// Refresh recordings but ensure deleted recording stays removed
    @MainActor
    private func refreshRecordingsPreservingDeletions(deletedRecordingId: UUID) async {
        guard let user = authManager.currentUser else {
            return
        }
        
        do {
            guard let accessToken = await authManager.getAccessToken() else {
                return
            }
            
            print("🔄 Refreshing recordings (preserving deletions)...")
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id
            )
            
            // Filter out all locally deleted recordings
            let filteredRecordings = fetchedRecordings.filter { !locallyDeletedIds.contains($0.id) }
            
            if filteredRecordings.count != fetchedRecordings.count {
                print("⚠️ Database still shows deleted recording(s), filtering them out")
            }
            
            // Apply local updates
            var merged = filteredRecordings
            for (id, localTrack) in locallyUpdatedRecordings {
                if let index = merged.firstIndex(where: { $0.id == id }) {
                    merged[index] = localTrack
                } else {
                    merged.append(localTrack)
                }
            }
            
            recordings = merged.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
            print("🔄 Refreshed: \(merged.count) recordings (deleted recording filtered out)")
        } catch {
            print("❌ Error refreshing recordings: \(error)")
        }
    }
    
    /// Smart refresh that preserves all local state (deletions and updates)
    @MainActor
    private func smartRefresh() async {
        guard let user = authManager.currentUser else {
            return
        }
        
        do {
            guard let accessToken = await authManager.getAccessToken() else {
                return
            }
            
            print("🔄 Smart refresh: preserving local state...")
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id
            )
            
            // Filter out locally deleted recordings
            var filtered = fetchedRecordings.filter { !locallyDeletedIds.contains($0.id) }
            
            // Check if any locally deleted recordings are no longer in the database (deletion confirmed)
            let fetchedIds = Set(fetchedRecordings.map { $0.id })
            let confirmedDeleted = locallyDeletedIds.filter { !fetchedIds.contains($0) }
            if !confirmedDeleted.isEmpty {
                print("✅ Database confirmed deletion of \(confirmedDeleted.count) recording(s), clearing from local tracking")
                locallyDeletedIds.subtract(confirmedDeleted)
            }
            
            // Apply local updates - check if database has newer data or keep local
            var merged: [AudioTrack] = []
            for fetched in filtered {
                if let localUpdate = locallyUpdatedRecordings[fetched.id] {
                    // Compare to see if database caught up
                    if fetched.name == localUpdate.name &&
                       fetched.category == localUpdate.category &&
                       fetched.description == localUpdate.description &&
                       fetched.icon == localUpdate.icon {
                        // Database caught up, use fetched and remove from local updates
                        merged.append(fetched)
                        locallyUpdatedRecordings.removeValue(forKey: fetched.id)
                        print("✅ Database caught up for \(fetched.id), removing from local updates")
                    } else {
                        // Database still has old data, keep local update
                        merged.append(localUpdate)
                        print("⚠️ Database still has old data for \(fetched.id), keeping local update")
                    }
                } else {
                    merged.append(fetched)
                }
            }
            
            // Add any local updates that aren't in the fetched list (shouldn't happen, but be safe)
            for (id, localTrack) in locallyUpdatedRecordings {
                if !merged.contains(where: { $0.id == id }) {
                    merged.append(localTrack)
                }
            }
            
            recordings = merged.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
            print("🔄 Smart refresh complete: \(merged.count) recordings (preserved \(locallyDeletedIds.count) deletions, \(locallyUpdatedRecordings.count) updates)")
        } catch {
            print("❌ Error in smart refresh: \(error)")
        }
    }
    
    /// Clear all cached user recordings from the app
    private func clearAllCachedRecordings() {
        print("🗑️ Clearing all cached user recordings...")
        
        // Set flag to prevent immediate reload
        shouldSkipNextLoad = true
        
        // 1. Clear from AudioManager (remove user recordings from tracks)
        audioManager.removeUserRecordings()
        
        // 2. Clear cache files for user recordings
        AudioCacheService.shared.clearUserRecordingsCache()
        
        // 3. Clear local state
        recordings = []
        
        print("✅ Cleared all cached user recordings (local state cleared, will not reload from database)")
    }
}

struct RecordingRow: View {
    let recording: AudioTrack
    let onDelete: () -> Void
    let onEdit: () -> Void
    @EnvironmentObject var audioManager: AudioManager
    @State private var recordingDuration: TimeInterval? = nil
    
    var body: some View {
        Button(action: {
            onEdit()
        }) {
            HStack(spacing: 20) {
                // Icon with Liquid Glass
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
                        .frame(width: 70, height: 70)
                        .liquidGlass(intensity: 0.9, cornerRadius: 35, blurIntensity: .light, opacityLevel: .content)
                        .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: recording.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if !recording.category.isEmpty {
                        Text(recording.category)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Show actual recording duration
                    if let duration = recording.duration {
                        Text(formatDuration(duration))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    } else if let recordedAt = recording.recordedAt {
                        Text(recordedAt, style: .date)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Edit indicator (chevron)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .liquidGlass(intensity: 1.0, cornerRadius: 24, blurIntensity: .medium, opacityLevel: .content)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
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

