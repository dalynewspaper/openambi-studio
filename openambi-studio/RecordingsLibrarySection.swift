import SwiftUI

/// Embeddable "Library" section for the **Field** room.
///
/// This is the redesign descendant of the now-deleted `UserRecordingsView`.
/// The old view was a standalone, NavigationView-wrapped sheet pushed from
/// Settings; in openambi 2.0 the library belongs in the Field room — the
/// same room where new recordings are captured — so it must be embeddable
/// inside a parent scroll.
///
/// Visual polish (palette-extracted circular cards, drag-up-to-blend) is
/// intentionally **not** in this commit. This is the structural scaffold:
/// load logic, smart-refresh, edit-sheet, and the same row UI today's
/// users already know. Phase 2.3 will replace `RecordingRow` with the
/// new card and add palette extraction.
struct RecordingsLibrarySection: View {

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var supabaseService = SupabaseService()

    @State private var recordings: [AudioTrack] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedRecording: AudioTrack? = nil

    // Local-state tracking so the UI stays correct even when Supabase
    // replication is briefly behind the in-memory view of the world.
    @State private var locallyDeletedIds: Set<UUID> = []
    @State private var locallyUpdatedRecordings: [UUID: AudioTrack] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader

            content
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 80) // breathing room above the PageRail
        .onAppear { loadRecordingsIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingSaved"))) { _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                await smartRefresh()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = errorMessage { Text(error) }
        }
        .sheet(item: $selectedRecording) { recording in
            EditRecordingView(
                recording: recording,
                onSave: { updatedTrack in
                    if let index = recordings.firstIndex(where: { $0.id == updatedTrack.id }) {
                        recordings[index] = updatedTrack
                    }
                    locallyUpdatedRecordings[updatedTrack.id] = updatedTrack
                    if let index = audioManager.tracks.firstIndex(where: { $0.id == updatedTrack.id }) {
                        audioManager.tracks[index] = updatedTrack
                    } else {
                        audioManager.loadTracks(audioManager.tracks + [updatedTrack])
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await refreshRecordingsPreservingLocalUpdates(updatedTrackId: updatedTrack.id)
                    }
                },
                onDelete: {
                    recordings.removeAll { $0.id == recording.id }
                    locallyDeletedIds.insert(recording.id)
                    locallyUpdatedRecordings.removeValue(forKey: recording.id)
                    audioManager.removeTrack(recording.id)
                    do {
                        try AudioCacheService.shared.removeCachedFile(recording.audioUrl)
                    } catch {
                        print("⚠️ Failed to clear cache for recording: \(error.localizedDescription)")
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await refreshRecordingsPreservingDeletions(deletedRecordingId: recording.id)
                    }
                }
            )
            .environmentObject(authManager)
        }
    }

    // MARK: - Section header

    /// Editorial-style header that doubles as the room's "library" label.
    /// Sits inline with the parent scroll — there is no NavigationView.
    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your collection")
                    .font(AuroraTypography.editorial(13, weight: .medium))
                    .kerning(2)
                    .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                    .textCase(.uppercase)

                Text("Library")
                    .font(AuroraTypography.display(28, weight: .semibold))
                    .foregroundColor(AuroraColors.TextOnAurora.primary)
            }

            Spacer(minLength: 0)

            if authManager.isAuthenticated {
                Button {
                    InstrumentFeedback.tap()
                    Task { @MainActor in await smartRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AuroraColors.IconOnAurora.inactive)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(.ultraThinMaterial).opacity(0.5)
                        )
                        .overlay(
                            Circle().strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1)
                .accessibilityLabel("Refresh library")
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !authManager.isAuthenticated {
            signedOutPlaceholder
        } else if isLoading {
            loadingPlaceholder
        } else if recordings.isEmpty {
            emptyPlaceholder
        } else {
            LazyVStack(spacing: 16) {
                ForEach(recordings) { recording in
                    RecordingRow(
                        recording: recording,
                        onDelete: {
                            Task { @MainActor in await smartRefresh() }
                        },
                        onEdit: {
                            selectedRecording = recording
                        }
                    )
                    .environmentObject(audioManager)
                }
            }
        }
    }

    // MARK: - Editorial placeholders (Phase 2.4 refines these further)

    private var signedOutPlaceholder: some View {
        VStack(spacing: 10) {
            Text("Sign in to begin your library")
                .font(AuroraTypography.editorial(18, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .multilineTextAlignment(.center)

            Text("Recordings sync to your account so you can find them on any device.")
                .font(AuroraTypography.ui(14))
                .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 14) {
            ProgressView().tint(AuroraColors.TextOnAurora.secondary)
            Text("Listening for your library…")
                .font(AuroraTypography.ui(13))
                .foregroundColor(AuroraColors.TextOnAurora.tertiary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Text("Capture your first sound")
                .font(AuroraTypography.editorial(20, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .multilineTextAlignment(.center)

            Text("Tap the orb above. Anything ambient — wind through a window, your kitchen at dawn — becomes a track you can layer with the rest of the world.")
                .font(AuroraTypography.ui(14))
                .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func loadRecordingsIfNeeded() {
        guard authManager.isAuthenticated else {
            isLoading = false
            return
        }
        loadRecordings()
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
                let fetched = try await supabaseService.fetchUserRecordings(
                    accessToken: accessToken,
                    userId: user.id
                )
                await MainActor.run {
                    recordings = fetched
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load recordings: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }

    @MainActor
    private func smartRefresh() async {
        guard let user = authManager.currentUser,
              let accessToken = await authManager.getAccessToken() else { return }
        do {
            let fetched = try await supabaseService.fetchUserRecordings(
                accessToken: accessToken,
                userId: user.id
            )
            var filtered = fetched.filter { !locallyDeletedIds.contains($0.id) }
            let fetchedIds = Set(fetched.map { $0.id })
            let confirmedDeleted = locallyDeletedIds.filter { !fetchedIds.contains($0) }
            if !confirmedDeleted.isEmpty {
                locallyDeletedIds.subtract(confirmedDeleted)
            }
            var merged: [AudioTrack] = []
            for rec in filtered {
                if let local = locallyUpdatedRecordings[rec.id] {
                    if rec.name == local.name &&
                       rec.category == local.category &&
                       rec.description == local.description &&
                       rec.icon == local.icon {
                        merged.append(rec)
                        locallyUpdatedRecordings.removeValue(forKey: rec.id)
                    } else {
                        merged.append(local)
                    }
                } else {
                    merged.append(rec)
                }
            }
            for (id, local) in locallyUpdatedRecordings where !merged.contains(where: { $0.id == id }) {
                merged.append(local)
            }
            recordings = merged.sorted { ($0.recordedAt ?? .distantPast) > ($1.recordedAt ?? .distantPast) }
            _ = filtered // silence unused-binding warning in release builds
        } catch {
            print("❌ smartRefresh: \(error)")
        }
    }

    @MainActor
    private func refreshRecordingsPreservingLocalUpdates(updatedTrackId: UUID) async {
        await smartRefresh()
    }

    @MainActor
    private func refreshRecordingsPreservingDeletions(deletedRecordingId: UUID) async {
        await smartRefresh()
    }
}

// MARK: - Recording row
//
// Moved here from the deleted `UserRecordingsView.swift`. The row's visual
// design (rectangular liquid-glass card) is preserved verbatim in 2.2 so
// this commit is purely structural. Phase 2.3 replaces this with the
// palette-extracted circular card.
struct RecordingRow: View {
    let recording: AudioTrack
    let onDelete: () -> Void
    let onEdit: () -> Void
    @EnvironmentObject var audioManager: AudioManager
    @State private var recordingDuration: TimeInterval? = nil

    var body: some View {
        Button(action: { onEdit() }) {
            HStack(spacing: 20) {
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

                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    if !recording.category.isEmpty {
                        Text(recording.category)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

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
