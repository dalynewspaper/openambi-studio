import SwiftUI
import AVFoundation
import UIKit

struct UserRecordingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var supabaseService = SupabaseService()
    
    private let localStorage = LocalRecordingStorage.shared
    private let syncService = RecordingSyncService.shared
    
    @State private var recordings: [AudioTrack] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedRecording: AudioTrack? = nil
    // Track local state that hasn't been persisted to database yet
    @State private var locallyDeletedIds: Set<UUID> = []
    @State private var locallyUpdatedRecordings: [UUID: AudioTrack] = [:]
    @State private var expectedNewRecordingIds: Set<UUID> = [] // Track newly saved recordings we expect to see
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                contentView
            }
            .navigationTitle("My Recordings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                setupNavigationBarAppearance()
            }
            .background(NavigationBarAppearanceModifier())
        }
        .onAppear {
            loadRecordings()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingSaved"))) { notification in
            handleRecordingSaved(notification: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingUpdated"))) { notification in
            handleRecordingUpdated(notification: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingDeleted"))) { notification in
            handleRecordingDeleted(notification: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingSavedLocally"))) { notification in
            handleRecordingSavedLocally(notification: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncLocalRecordings"))) { _ in
            handleSyncLocalRecordings()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            handleAuthChange(isAuthenticated: isAuthenticated)
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
        .sheet(item: $selectedRecording) { recording in
            editRecordingSheet(recording: recording)
        }
    }
    
    // MARK: - Sheet Content
    @ViewBuilder
    private func editRecordingSheet(recording: AudioTrack) -> some View {
            EditRecordingView(
                recording: recording,
                onSave: { updatedTrack in
                handleRecordingSave(updatedTrack: updatedTrack)
            },
            onDelete: {
                handleRecordingDelete(recording: recording)
            }
        )
        .environmentObject(authManager)
    }
    
    private func handleRecordingSave(updatedTrack: AudioTrack) {
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
    }
    
    private func handleRecordingDelete(recording: AudioTrack) {
                    // Remove from local recordings list immediately for instant UI feedback
                    recordings.removeAll { $0.id == recording.id }
                    
                    // Track this as locally deleted
                    locallyDeletedIds.insert(recording.id)
                    // Remove from local updates if it was there
                    locallyUpdatedRecordings.removeValue(forKey: recording.id)
                    
                    // Remove from AudioManager using the proper method
                    audioManager.removeTrack(recording.id)
                    
                    // Remove from local storage if it exists there
                    do {
                        try localStorage.deleteRecording(id: recording.id)
                        print("🗑️ Removed recording from local storage: \(recording.id.uuidString.prefix(8))")
                    } catch {
                        // Not a problem if it doesn't exist in local storage
                        print("ℹ️ Recording not in local storage (or already removed): \(error.localizedDescription)")
                    }
                    
                    // Clear cache for this specific recording
                    do {
                        try AudioCacheService.shared.removeCachedFile(recording.audioUrl)
                        print("🗑️ Cleared cache for recording: \(recording.audioUrl)")
                    } catch {
                        print("⚠️ Failed to clear cache for recording: \(error.localizedDescription)")
                    }
                    
                    // Clear the Supabase cache to force fresh fetch
                    if let user = authManager.currentUser {
                        supabaseService.clearUserRecordingsCache(userId: user.id)
                    }
                    
                    // Refresh list from database after a delay, but keep it removed locally
                    Task { @MainActor in
                        // Longer delay to allow for database replication/consistency
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                        // Refresh, but ensure deleted recording stays removed
                        await refreshRecordingsPreservingDeletions(deletedRecordingId: recording.id)
                    }
                }
    
    // MARK: - View Components
    private var backgroundView: some View {
        AppTheme.background
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if recordings.isEmpty {
            emptyStateView
        } else {
            recordingsListView
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .tint(.white)
            .scaleEffect(1.2)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            emptyStateIcon
            Text("No Recordings")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppColors.primaryText) // Phase 4: Vibrant color
            Text("Recordings you save will appear here")
                .font(.system(size: 16))
                .foregroundColor(AppColors.tertiaryText) // Phase 4: Vibrant color
        }
    }
    
    private var emptyStateIcon: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .frame(width: 120, height: 120)
                .overlay(emptyStateGradient)
                .overlay(emptyStateBorder)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
            
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(AppColors.tertiaryText) // Phase 4: Vibrant color
        }
    }
    
    private var emptyStateGradient: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 60
                )
            )
    }
    
    private var emptyStateBorder: some View {
        Circle()
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
    }
    
    private var recordingsListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(recordings) { recording in
                    RecordingRow(
                        recording: recording,
                        onDelete: {
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
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                refreshButton
                doneButton
            }
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            print("🔄 Manual refresh triggered")
            Task { @MainActor in
                await smartRefresh()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
        }
        .disabled(isLoading)
    }
    
    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
        .foregroundColor(.white.opacity(0.8))
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Notification Handlers
    private func handleRecordingSaved(notification: Notification) {
        // INSTANT UPDATE: Immediately load from local storage and add to list
        if let recordingIdString = notification.userInfo?["recordingId"] as? String,
           let recordingId = UUID(uuidString: recordingIdString) {
            expectedNewRecordingIds.insert(recordingId)
            print("🔄 Received RecordingSaved notification for \(recordingIdString.prefix(8)) - adding instantly")
            
            // CRITICAL: Clear cache so we get fresh data from database
            if let user = authManager.currentUser {
                supabaseService.clearUserRecordingsCache(userId: user.id)
            }
            
            // Immediately try to load from local storage for instant UI update
            Task { @MainActor in
                let localRecordings = loadLocalRecordings()
                if let track = localRecordings.first(where: { $0.id == recordingId }) {
                    // Add to list immediately if not already present
                    if !recordings.contains(where: { $0.id == recordingId }) {
                        recordings.append(track)
                        recordings = recordings.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
                        print("✅ Instantly added recording to list: \(track.name)")
                    }
                }
                
                // Then refresh from database in background (handles read replica lag)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                await smartRefreshWithExpectedRecordings()
            }
        } else {
            // Fallback: refresh after delay if we can't get the ID
            Task { @MainActor in
                // Clear cache before refreshing
                if let user = authManager.currentUser {
                    supabaseService.clearUserRecordingsCache(userId: user.id)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await smartRefresh()
            }
        }
    }
    
    private func handleRecordingUpdated(notification: Notification) {
        // Refresh when a recording is updated
        print("🔄 Received RecordingUpdated notification - refreshing recordings list")
        
        // Clear cache so we get fresh data
        if let user = authManager.currentUser {
            supabaseService.clearUserRecordingsCache(userId: user.id)
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await smartRefresh()
        }
    }
    
    private func handleRecordingDeleted(notification: Notification) {
        // Refresh when a recording is deleted
        print("🔄 Received RecordingDeleted notification - refreshing recordings list")
        
        // Clear cache so we get fresh data
        if let user = authManager.currentUser {
            supabaseService.clearUserRecordingsCache(userId: user.id)
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await smartRefresh()
        }
    }
    
    private func handleRecordingSavedLocally(notification: Notification) {
        // INSTANT UPDATE: Immediately load from local storage
        print("🔄 Received RecordingSavedLocally notification - adding instantly")
        
        Task { @MainActor in
            // Immediately reload local recordings and add to list
            let localRecordings = loadLocalRecordings()
            var updatedRecordings = recordings
            
            // Add any new local recordings that aren't in the list
            for track in localRecordings {
                if !updatedRecordings.contains(where: { $0.id == track.id }) {
                    updatedRecordings.append(track)
                    print("✅ Instantly added local recording: \(track.name)")
                }
            }
            
            // Update list immediately
            recordings = updatedRecordings.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
            
            // Try to sync if online (background)
            await syncService.manualSync(authManager: authManager)
            
            // Refresh from database after sync
            await smartRefresh()
        }
    }
    
    private func handleSyncLocalRecordings() {
        // Sync local recordings when network becomes available
        Task { @MainActor in
            await syncService.manualSync(authManager: authManager)
            await smartRefresh()
        }
    }
    
    private func handleAuthChange(isAuthenticated: Bool) {
        // When user signs in, try to sync local recordings
        if isAuthenticated {
            Task { @MainActor in
                await syncService.manualSync(authManager: authManager)
                await smartRefresh()
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadRecordings() {
        guard let user = authManager.currentUser else {
            errorMessage = "You must be signed in to view recordings."
            showError = true
            isLoading = false
            return
        }
        
        // Clear cache on app start to ensure fresh data
        supabaseService.clearUserRecordingsCache(userId: user.id)
        
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
                
                // OPTIMISTIC UI: Show local recordings immediately (instant feedback)
                await MainActor.run {
                    let localRecordings = loadLocalRecordings()
                    if !localRecordings.isEmpty {
                        recordings = localRecordings.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
                        isLoading = false // Show UI immediately with local data
                        print("✅ Showing \(localRecordings.count) local recordings immediately (optimistic UI)")
                    }
                }
                
                // Single fetch attempt (no retry loop - 10x faster!)
                // If read replica lag occurs, recordings will sync in background
                // Bypass cache since we just cleared it to ensure fresh data
                let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                    accessToken: accessToken,
                    userId: user.id,
                    bypassCache: true
                )
                
                print("✅ Fetched \(fetchedRecordings.count) recordings from cloud")
                print("📋 Recording IDs: \(fetchedRecordings.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" }.joined(separator: ", "))")
                
                // Merge cloud and local recordings (prefer cloud, fallback to local)
                await MainActor.run {
                    let localRecordings = loadLocalRecordings()
                    
                    // Filter out locally deleted recordings (handles read replica lag)
                    var allRecordings = fetchedRecordings.filter { !locallyDeletedIds.contains($0.id) }
                    
                    if allRecordings.count != fetchedRecordings.count {
                        print("🗑️ Filtered out \(fetchedRecordings.count - allRecordings.count) locally deleted recording(s) from load")
                    }
                    
                    // Create set of cloud recording IDs for fast lookup
                    let cloudRecordingIds = Set(fetchedRecordings.map { $0.id })
                    
                    // Add local recordings that aren't in cloud (unsynced or new)
                    // But exclude locally deleted ones AND ones that are in cloud (cloud is source of truth)
                    for localTrack in localRecordings {
                        if locallyDeletedIds.contains(localTrack.id) {
                            // Clean up: remove from local storage if it's been deleted
                            do {
                                try localStorage.deleteRecording(id: localTrack.id)
                                print("🗑️ Cleaned up deleted recording from local storage: \(localTrack.id.uuidString.prefix(8))")
                            } catch {
                                // Not critical if it fails
                                print("ℹ️ Could not remove from local storage: \(error.localizedDescription)")
                            }
                        } else if !cloudRecordingIds.contains(localTrack.id) {
                            // Local recording not in cloud - could be unsynced or deleted
                            // Only include if it's recently created (within last hour) - likely unsynced
                            // Otherwise assume it's deleted and clean it up
                            let oneHourAgo = Date().addingTimeInterval(-3600)
                            if let recordedAt = localTrack.recordedAt, recordedAt > oneHourAgo {
                                // Recent recording, likely not synced yet - include it
                                allRecordings.append(localTrack)
                                print("📱 Including unsynced local recording: \(localTrack.name)")
                            } else {
                                // Old recording not in cloud - likely deleted, clean it up
                                do {
                                    try localStorage.deleteRecording(id: localTrack.id)
                                    print("🗑️ Cleaned up orphaned deleted recording from local storage: \(localTrack.name) (\(localTrack.id.uuidString.prefix(8)))")
                                } catch {
                                    print("ℹ️ Could not remove orphaned recording from local storage: \(error.localizedDescription)")
                                }
                            }
                        }
                        // If localTrack.id IS in cloudRecordingIds, we already have it from cloud (prefer cloud)
                    }
                    
                    recordings = allRecordings.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
                    isLoading = false
                    
                    // Clean up any orphaned deleted recordings in background
                    // This ensures deleted recordings are removed from local storage
                    let cloudIds = Set(fetchedRecordings.map { $0.id })
                    Task {
                        await cleanupOrphanedDeletedRecordings(cloudRecordingIds: cloudIds)
                    }
                }
                
                // Background sync for any missing recordings (non-blocking)
                // This handles read replica lag without blocking the UI
                Task.detached(priority: .utility) {
                    await syncService.manualSync(authManager: authManager)
                }
                
            } catch {
                print("❌ Error loading recordings: \(error)")
                await MainActor.run {
                    // If we have local recordings, still show them even on error
                    let localRecordings = loadLocalRecordings()
                    if !localRecordings.isEmpty && recordings.isEmpty {
                        recordings = localRecordings.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
                        print("✅ Showing \(localRecordings.count) local recordings despite cloud error")
                    }
                    
                    // Only show error if we have no recordings at all
                    if recordings.isEmpty {
                        errorMessage = "Failed to load recordings: \(error.localizedDescription)"
                        showError = true
                    }
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
            // Clear cache and bypass it for fresh data
            supabaseService.clearUserRecordingsCache(userId: user.id)
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id,
                bypassCache: true
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
            // Clear cache and bypass it for fresh data
            supabaseService.clearUserRecordingsCache(userId: user.id)
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id,
                bypassCache: true
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
            // Clear cache and bypass it for fresh data
            supabaseService.clearUserRecordingsCache(userId: user.id)
            let fetchedRecordings = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id,
                bypassCache: true
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
        await smartRefreshWithExpectedRecordings()
    }
    
    /// Smart refresh with retry logic for expected recordings (handles read replica lag)
    @MainActor
    private func smartRefreshWithExpectedRecordings() async {
        guard let user = authManager.currentUser else {
            return
        }
        
        do {
            guard let accessToken = await authManager.getAccessToken() else {
                return
            }
            
            print("🔄 Smart refresh: preserving local state...")
            
            // If we're expecting new recordings, retry until we see them (handles read replica lag)
            let expectedIds = expectedNewRecordingIds
            var fetchedRecordings: [AudioTrack] = []
            let maxAttempts = expectedIds.isEmpty ? 1 : 8 // More attempts if expecting new recordings
            var allExpectedFound = false
            
            for attempt in 1...maxAttempts {
                // Always bypass cache when expecting new recordings or on first attempt after save
                let bypassCache = attempt == 1 || !expectedIds.isEmpty
                let attemptRecordings = try await supabaseService.fetchUserRecordings(
                    accessToken: accessToken,
                    userId: user.id,
                    bypassCache: bypassCache
                )
                
                fetchedRecordings = attemptRecordings
                
                // Check if all expected recordings are present
                if !expectedIds.isEmpty {
                    let fetchedIds = Set(attemptRecordings.map { $0.id })
                    let foundExpected = expectedIds.filter { fetchedIds.contains($0) }
                    
                    if foundExpected.count == expectedIds.count {
                        print("✅ All expected recordings found on attempt \(attempt): \(foundExpected.map { $0.uuidString.prefix(8) }.joined(separator: ", "))")
                        allExpectedFound = true
                        // Clear from expected list since we found them
                        expectedNewRecordingIds.subtract(foundExpected)
                        break
                    } else {
                        print("⏳ Found \(foundExpected.count)/\(expectedIds.count) expected recordings on attempt \(attempt), waiting for read replica...")
                        if attempt < maxAttempts {
                            let delay = Double(attempt) * 0.5 // 0.5s, 1.0s, 1.5s, etc.
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                } else {
                    // No expected recordings, one attempt is enough
                    break
                }
            }
            
            if !expectedIds.isEmpty && !allExpectedFound {
                print("⚠️ Some expected recordings not found after \(maxAttempts) attempts - read replica lag may be longer than expected")
                // Keep them in expected list for next refresh
            }
            
            // Filter out locally deleted recordings
            let filtered = fetchedRecordings.filter { !locallyDeletedIds.contains($0.id) }
            
            // Check if any locally deleted recordings are no longer in the database (deletion confirmed)
            let fetchedIds = Set(fetchedRecordings.map { $0.id })
            let confirmedDeleted = locallyDeletedIds.filter { !fetchedIds.contains($0) }
            if !confirmedDeleted.isEmpty {
                print("✅ Database confirmed deletion of \(confirmedDeleted.count) recording(s), clearing from local tracking and storage")
                // Clean up from local storage
                for deletedId in confirmedDeleted {
                    do {
                        try localStorage.deleteRecording(id: deletedId)
                        print("🗑️ Cleaned up confirmed deleted recording from local storage: \(deletedId.uuidString.prefix(8))")
                    } catch {
                        // Not critical if it fails
                    }
                }
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
            
            // Add local recordings that aren't synced yet
            // But filter out deleted ones and clean them up
            let localRecordings = loadLocalRecordings()
            for localTrack in localRecordings {
                if locallyDeletedIds.contains(localTrack.id) {
                    // Clean up: remove from local storage if it's been deleted
                    do {
                        try localStorage.deleteRecording(id: localTrack.id)
                        print("🗑️ Cleaned up deleted recording from local storage during refresh: \(localTrack.id.uuidString.prefix(8))")
                    } catch {
                        // Not critical if it fails
                    }
                } else if !merged.contains(where: { $0.id == localTrack.id }) {
                    merged.append(localTrack)
                }
            }
            
            recordings = merged.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
            print("🔄 Smart refresh complete: \(merged.count) recordings (preserved \(locallyDeletedIds.count) deletions, \(locallyUpdatedRecordings.count) updates)")
        } catch {
            print("❌ Error in smart refresh: \(error)")
            // Still load local recordings even if cloud fetch fails, but filter deleted ones
            let localRecordings = loadLocalRecordings().filter { !locallyDeletedIds.contains($0.id) }
            recordings = localRecordings.sorted { ($0.recordedAt ?? Date.distantPast) > ($1.recordedAt ?? Date.distantPast) }
        }
    }
    
    // MARK: - Navigation Bar Setup (Phase 1: Liquid Glass)
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Phase 1: Use Liquid Glass material (regular material for blur effect)
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        appearance.backgroundEffect = blurEffect
        
        // Vibrant white text for proper contrast on Liquid Glass
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        // Set for all appearance types to persist during scrolling
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
    }
    
    // MARK: - Load Local Recordings
    /// Loads locally stored recordings and converts them to AudioTracks
    @MainActor
    private func loadLocalRecordings() -> [AudioTrack] {
        let localMetadata = localStorage.loadLocalRecordings()
        var localTracks: [AudioTrack] = []
        
        for metadata in localMetadata {
            if let track = localStorage.toAudioTrack(metadata) {
                localTracks.append(track)
            }
        }
        
        print("📱 Loaded \(localTracks.count) local recording(s)")
        return localTracks
    }
    
    /// Cleans up local recordings that are deleted in the database
    /// This ensures deleted recordings are removed from local storage even after app reinstall
    @MainActor
    private func cleanupOrphanedDeletedRecordings(cloudRecordingIds: Set<UUID>) async {
        let localRecordings = loadLocalRecordings()
        var cleanedCount = 0
        
        for localTrack in localRecordings {
            // If local recording is not in cloud results and not in locallyDeletedIds, it might be deleted
            if !cloudRecordingIds.contains(localTrack.id) && !locallyDeletedIds.contains(localTrack.id) {
                // Check if it's a recent recording (might just not be synced yet)
                let oneHourAgo = Date().addingTimeInterval(-3600)
                if let recordedAt = localTrack.recordedAt, recordedAt <= oneHourAgo {
                    // Old recording not in cloud - likely deleted, clean it up
                    do {
                        try localStorage.deleteRecording(id: localTrack.id)
                        cleanedCount += 1
                        print("🗑️ Cleaned up orphaned deleted recording: \(localTrack.name) (\(localTrack.id.uuidString.prefix(8)))")
                    } catch {
                        print("ℹ️ Could not remove orphaned recording: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        if cleanedCount > 0 {
            print("✅ Cleaned up \(cleanedCount) orphaned deleted recording(s) from local storage")
        }
    }
}

struct RecordingRow: View {
    let recording: AudioTrack
    let onDelete: () -> Void
    let onEdit: () -> Void
    @EnvironmentObject var audioManager: AudioManager
    @State private var recordingDuration: TimeInterval? = nil
    @State private var isPreviewing = false
    @State private var previewPlayer: AVPlayer?
    
    var body: some View {
        HStack(spacing: 20) {
            iconView
            infoView
            Spacer()
            // Preview button
            previewButton
            chevronView
        }
        .padding(20)
        .background(cardBackground)
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
        .onTapGesture {
            // Tap to edit (restore original behavior)
            onEdit()
        }
    }
    
    private var iconView: some View {
        // Phase 3: Use CircularIcon component for consistent design
        CircularIcon(
            icon: recording.icon,
            color: .white, // Neutral color for recordings
            isActive: isPreviewing,
            size: .primary
        )
        .scaleEffect(isPreviewing ? 1.1 : 1.0)
        .animation(AppTheme.Animation.liquidSpring, value: isPreviewing)
    }
    
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recording.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
            
            if !recording.category.isEmpty {
                Text(recording.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.tertiaryText) // Phase 4: Vibrant color
            }
            
            if let duration = recording.duration {
                Text(formatDuration(duration))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
            } else if let recordedAt = recording.recordedAt {
                Text(recordedAt, style: .date)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
            }
        }
    }
                
    private var previewButton: some View {
        Button(action: {
            previewRecording()
        }) {
            Image(systemName: isPreviewing ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var chevronView: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.4))
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.ultraThinMaterial)
            .opacity(0.65)
            .overlay(cardGradient)
            .overlay(cardBorder)
    }
    
    private var cardGradient: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
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
        player.volume = 0.4
        
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

// MARK: - Navigation Bar Appearance Modifier (Phase 1: Liquid Glass)
struct NavigationBarAppearanceModifier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            applyNavigationBarAppearance()
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Re-apply on every update to ensure it persists during scrolling
        applyNavigationBarAppearance()
    }
    
    private func applyNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        
        // Phase 1: Use Liquid Glass material for navigation bar
        // Configure with transparent background to allow Liquid Glass to show through
        appearance.configureWithTransparentBackground()
        
        // Use regular material for Liquid Glass effect (blurs background, maintains legibility)
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        appearance.backgroundEffect = blurEffect
        
        // Set vibrant white text for proper contrast on Liquid Glass
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        // Set for all appearance types to persist during scrolling
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
    }
}

