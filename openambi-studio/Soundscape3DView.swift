import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Main 3D Soundscape View with Pull-to-Activate UX
struct Soundscape3DView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var supabaseService = SupabaseService()
    @Binding var selectedTab: Int // Binding to navigate to recording tab
    @State private var orbPositions: [UUID: CGPoint] = [:]
    @State private var draggingTrackId: UUID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var soundsInVolumeMode: Set<UUID> = [] // Track which sounds are in volume mode
    @State private var selectedTrackForModal: AudioTrack? = nil // Track selected for modal from grid
    @State private var isDraggingToDock: Set<UUID> = [] // Track which items are being dragged to dock
    @State private var dockFrame: CGRect = .zero // Track dock frame for drop detection
    @State private var gridItemPositions: [UUID: CGPoint] = [:] // Track grid item positions for drag-to-dock
    @State private var uiMaterialized = false // Track if UI has materialized from cinematic
    @State private var hasLoadedData = false // Track if data has been loaded to prevent reloading
    
    // Constants
    private let dockHeight: CGFloat = 0.1 // Bottom 10% is dock
    private let minActiveHeight: CGFloat = 0.12 // 12% from bottom = minimum active
    private let maxVolumeHeight: CGFloat = 0.9 // 90% from bottom = max volume
    
    // Helper to calculate dock width matching 3 grid tiles
    private func calculateDockWidth() -> CGFloat {
        let tileSize: CGFloat = 110 // baseSize from GridSoundItem
        let columnSpacing: CGFloat = AppSpacing.md // 24pt - matches grid column spacing
        return (tileSize * 3) + (columnSpacing * 2) // 330 + 48 = 378pt
    }
    
    // Active tracks for background animations (only tracks with volume > 0)
    private var activeTracksForBackground: [AudioTrack] {
        audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
    }
    
    // Active tracks for dock (all active tracks, regardless of volume) - sorted by volume (loudest first)
    private var activeTracks: [AudioTrack] {
        audioManager.tracks.filter { $0.isActive }
            .sorted { $0.volume > $1.volume } // Sort by volume descending (loudest first)
    }
    
    // Grid tracks: maintain original order (no sorting by volume)
    // Tiles should stay in their fixed positions
    private var sortedTracks: [AudioTrack] {
        // Return tracks in their original order - no sorting
        return audioManager.tracks
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaInsets = geometry.safeAreaInsets
            // ContentView (and the TabView children) call .ignoresSafeArea(.all)
            // to let AuroraGlass washes bleed edge-to-edge. As a side effect the
            // GeometryReader here reports zero insets, which would crash the
            // StudioHeader into the Dynamic Island. Fall back to the window's
            // real insets in that case so the editorial header always sits
            // beneath the device chrome.
            let topSafeArea = max(safeAreaInsets.top, WindowMetrics.topInset)
            let bottomSafeArea = max(safeAreaInsets.bottom, WindowMetrics.bottomInset)
            // Enhanced safe area handling with additional padding for premium feel
            let effectiveTopSafeArea = topSafeArea + AppSpacing.safeAreaTopPadding
            let effectiveBottomSafeArea = bottomSafeArea + AppSpacing.safeAreaBottomPadding
            
            ZStack {
                // Base background color - always visible, matches app theme
                AppTheme.background
                    .ignoresSafeArea(.all)
                
                // Immersive background - extends into safe areas, overlays base
                ImmersiveBackground(activeTracks: activeTracksForBackground)
                    .ignoresSafeArea(.all)
                    .opacity(uiMaterialized ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.4).delay(0.1), value: uiMaterialized)
                
                // Always calculate approximate dock frame for drop detection (even when dock is empty)
                // This allows dragging first track to dock
                Color.clear
                    .onAppear {
                        // Calculate approximate dock position at bottom of screen
                        let approximateDockHeight: CGFloat = 100
                        let volumeSliderHeight: CGFloat = 40
                        let dockY = geometry.size.height - bottomSafeArea - approximateDockHeight - volumeSliderHeight
                        let calculatedFrame = CGRect(
                            x: 0,
                            y: dockY,
                            width: geometry.size.width,
                            height: approximateDockHeight
                        )
                        dockFrame = calculatedFrame
                        print("📍 Calculated dock frame (onAppear): \(calculatedFrame)")
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        // Recalculate when screen size changes
                        let approximateDockHeight: CGFloat = 100
                        let volumeSliderHeight: CGFloat = activeTracks.isEmpty ? 0 : 40
                        let dockY = newSize.height - bottomSafeArea - approximateDockHeight - volumeSliderHeight
                        let calculatedFrame = CGRect(
                            x: 0,
                            y: dockY,
                            width: newSize.width,
                            height: approximateDockHeight
                        )
                        dockFrame = calculatedFrame
                        print("📍 Calculated dock frame (size change): \(calculatedFrame)")
                    }
                
                // Studio header (Phase 3.1) — editorial scene mood + place chip.
                // Sits at the very top of every Studio appearance, regardless
                // of whether tracks are active or not, so the IA reads from
                // the moment the user lands.
                if selectedTrackForModal == nil {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: effectiveTopSafeArea + AppSpacing.sm)

                        StudioHeader(activeTracks: activeTracks)
                            .opacity(uiMaterialized ? 1.0 : 0.0)
                            .offset(y: uiMaterialized ? 0 : -8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: uiMaterialized)

                        Spacer()
                    }
                    .zIndex(103) // Above master volume slider
                }

                // Master Volume Slider - positioned below the studio header,
                // between the safe area and the sound icons. Only visible
                // when there is something to control.
                if !activeTracks.isEmpty && selectedTrackForModal == nil {
                    VStack {
                        Spacer()
                            .frame(height: effectiveTopSafeArea + AppSpacing.xl + AppSpacing.md + AppSpacing.md)

                        MasterVolumeSlider(audioManager: audioManager)
                            .padding(.horizontal, AppSpacing.edgePadding)
                            .zIndex(102) // Above everything
                            .allowsHitTesting(true) // Ensure it can receive touches
                            .opacity(uiMaterialized ? 1.0 : 0.0)
                            .offset(y: uiMaterialized ? 0 : 10)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: uiMaterialized)

                        Spacer()
                    }
                    .zIndex(102) // Above grid
                }
                
                // Grid layout for all sound elements (active tracks first) - hide when modal is open
                if selectedTrackForModal == nil {
                    // When there are active tracks the master volume slider sits
                    // between the header and the grid. The slider's tap-target
                    // is 44pt and we want a calm 16pt of breathing space below
                    // it before the first row of orbs starts — otherwise the
                    // slider's rail draws straight through the top row of
                    // tiles (the bug visible in the launch screenshots).
                    let sliderClearance: CGFloat = activeTracks.isEmpty ? 0 : (44 + AppSpacing.sm)

                    ScrollView {
                        VStack(spacing: 0) {
                            // Top spacing - drop icons down for better visual balance
                            // Add 48px total margin (24px + 24px) to push elements into the app
                            Spacer()
                                .frame(height: effectiveTopSafeArea + AppSpacing.xl + AppSpacing.md + AppSpacing.md + sliderClearance)
                            
                            // Sound elements grid - iOS home screen style spacing
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: AppSpacing.md), // Generous spacing between columns (iOS style)
                                    GridItem(.flexible(), spacing: AppSpacing.md),
                                    GridItem(.flexible(), spacing: AppSpacing.md),
                                    GridItem(.flexible(), spacing: 0) // No trailing spacing to prevent cutoff
                                ],
                                spacing: AppSpacing.lg // Generous row spacing (iOS home screen style)
                            ) {
                                ForEach(sortedTracks, id: \.id) { track in
                                    GridSoundItem(
                                        track: Binding(
                                            get: { track },
                                            set: { newValue in
                                                if let index = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
                                                    audioManager.tracks[index] = newValue
                                                }
                                            }
                                        ),
                                        audioManager: audioManager,
                                        soundsInVolumeMode: $soundsInVolumeMode,
                                        isDraggingToDock: $isDraggingToDock,
                                        dockFrame: dockFrame,
                                        itemPosition: gridItemPositions[track.id] ?? .zero,
                                        onLongPress: {
                                            // Activate track and open modal
                                            if let index = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
                                                var updatedTrack = audioManager.tracks[index]
                                                if !updatedTrack.isActive || updatedTrack.volume == 0 {
                                                    updatedTrack.isActive = true
                                                    updatedTrack.volume = 0.5 // Set default volume
                                                    audioManager.tracks[index] = updatedTrack
                                                    audioManager.toggleTrack(track.id, isActive: true)
                                                    audioManager.updateTrackVolume(track.id, volume: 0.5)
                                                }
                                            }
                                            // Open modal
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                selectedTrackForModal = track
                                            }
                                        }
                                    )
                                    .opacity(uiMaterialized ? 1.0 : 0.0)
                                    .offset(y: uiMaterialized ? 0 : 20)
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(sortedTracks.firstIndex(where: { $0.id == track.id }) ?? 0) * 0.03),
                                        value: uiMaterialized
                                    )
                                }
                            }
                            .padding(EdgeInsets(
                                top: 0, // No top padding since we have spacer
                                leading: AppSpacing.lg, // Generous edge padding (iOS style)
                                bottom: AppSpacing.xxl + effectiveBottomSafeArea + AppSpacing.md, // Bottom padding with safe area + 24px margin
                                trailing: AppSpacing.lg // Generous edge padding (iOS style)
                            ))
                            .frame(maxWidth: .infinity) // Ensure grid doesn't overflow
                            .zIndex(0) // Grid below dock
                        }
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, 
                                          value: scrollGeometry.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .scrollDisabled(!soundsInVolumeMode.isEmpty || !isDraggingToDock.isEmpty) // Disable scrolling when dragging or in volume mode
                .zIndex(0) // Grid below dock
                .onPreferenceChange(GridItemPositionPreferenceKey.self) { positions in
                    gridItemPositions = positions
                }
                }
                
                // Dock - always shown at bottom when there are active tracks - hide when modal is open
                if !activeTracks.isEmpty && selectedTrackForModal == nil {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Dock at bottom - full width, matches iOS system dock
                        ActiveMixDock(
                            activeTracks: activeTracks,
                            audioManager: audioManager,
                            soundsInVolumeMode: $soundsInVolumeMode,
                            selectedTrackForModal: $selectedTrackForModal,
                            screenHeight: geometry.size.height,
                            bottomSafeArea: bottomSafeArea,
                            dockWidth: nil, // Full width
                            onDockFrameChange: { frame in
                                // Only update if frame is valid (non-zero)
                                if frame.width > 0 && frame.height > 0 {
                                    dockFrame = frame
                                    print("📍 Dock frame updated: \(frame)")
                                }
                            }
                        )
                        .zIndex(101) // Dock above background
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .opacity(uiMaterialized ? 1.0 : 0.0)
                        .offset(y: uiMaterialized ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: uiMaterialized)
                        .padding(.bottom, AppSpacing.md) // Add 24px margin to push dock up into the app
                    }
                    .zIndex(100) // Entire dock container above grid
                }
                
                // Modal overlay (Phase 3.4) — opens like an aperture
                // dilating from the orb. The .scale(0.86, anchor: .center)
                // + opacity pair, paired with the spring already running
                // on selection/dismissal, makes the sheet feel like the
                // grid orb itself is unfurling rather than a panel
                // arriving from another surface.
                if let track = selectedTrackForModal {
                    SoundControlModal(
                        track: track,
                        audioManager: audioManager,
                        topSafeArea: effectiveTopSafeArea,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTrackForModal = nil
                            }
                        }
                    )
                    .transition(
                        .scale(scale: 0.86, anchor: .center)
                            .combined(with: .opacity)
                    )
                }
            }
        }
        .task {
            // Load data asynchronously - only once to prevent resetting tracks
            if !hasLoadedData {
                await loadData()
                hasLoadedData = true
            }
            
            // Trigger UI materialization animation after a brief delay
            // This creates smooth staggered reveal when transitioning from cinematic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    uiMaterialized = true
                }
            }
        }
        .onDisappear {
            // Clean up
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingSaved"))) { notification in
            // Refresh user recordings when a new one is saved
            // With RLS fix, recordings appear immediately, so just a simple refresh is needed
            print("🔄 Soundscape3DView: Received RecordingSaved notification - refreshing user recordings")
            
            Task {
                guard let user = authManager.currentUser else { return }
                
                // Small delay to ensure the recording is added to AudioManager first
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                do {
                    guard let accessToken = await authManager.getAccessToken() else { return }
                    
                    // Fetch all user recordings (RLS now works correctly)
                    let userRecordings = try await supabaseService.fetchUserRecordings(
                        accessToken: accessToken,
                        userId: user.id
                    )
                    
                    print("✅ Soundscape3DView: Fetched \(userRecordings.count) user recordings")
                    
                    // Merge with existing tracks (keep ambient sounds and frequency tracks)
                    await MainActor.run {
                        let existingTracks = audioManager.tracks.filter { !$0.isUserRecording }
                        let allTracks = existingTracks + userRecordings
                        audioManager.loadTracks(allTracks)
                        print("✅ Soundscape3DView: Updated AudioManager with \(allTracks.count) total tracks (\(userRecordings.count) user recordings)")
                    }
                } catch {
                    print("⚠️ Soundscape3DView: Failed to refresh recordings: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func isAboveDock(_ track: AudioTrack, in size: CGSize) -> Bool {
        // Show orb if it's positioned above the dock area
        // Check if track has a stored position above dock
        if let storedPosition = orbPositions[track.id] {
            let dockTop = size.height * (1 - dockHeight)
            return storedPosition.y < dockTop - 20 // 20pt buffer above dock
        }
        // If no stored position, check if track is active (should be above dock)
        return track.isActive && track.volume > 0
    }
    
    private func getOrbPosition(for track: AudioTrack, in size: CGSize) -> CGPoint {
        if let storedPosition = orbPositions[track.id] {
            // Apply collision avoidance for active orbs
            return avoidOverlap(position: storedPosition, for: track.id, in: size)
        }
        // Default to dock position
        return getDockPosition(for: track, in: size)
    }
    
    private func avoidOverlap(position: CGPoint, for trackId: UUID, in size: CGSize) -> CGPoint {
        let minDistance = AppSpacing.orbMinDistance // Minimum distance between orbs
        var adjustedPosition = position
        
        // Only apply collision avoidance if orb is above dock
        let dockTop = size.height * (1 - dockHeight)
        guard position.y < dockTop else {
            return position // In dock, no collision avoidance needed
        }
        
        // Check against all other active orbs
        for (otherId, otherPosition) in orbPositions where otherId != trackId {
            let otherDockTop = size.height * (1 - dockHeight)
            guard otherPosition.y < otherDockTop else { continue } // Skip orbs in dock
            
            let distance = sqrt(
                pow(adjustedPosition.x - otherPosition.x, 2) +
                pow(adjustedPosition.y - otherPosition.y, 2)
            )
            
            if distance < minDistance {
                // Push away from overlapping orb
                let angle = atan2(
                    adjustedPosition.y - otherPosition.y,
                    adjustedPosition.x - otherPosition.x
                )
                let pushDistance = (minDistance - distance) * 0.6 // Gentle push
                adjustedPosition.x += cos(angle) * pushDistance
                adjustedPosition.y += sin(angle) * pushDistance
                
                // Keep within bounds (avoid hub and dock)
                adjustedPosition.x = max(80, min(size.width - 80, adjustedPosition.x))
                adjustedPosition.y = max(size.height * 0.3, min(size.height * 0.85, adjustedPosition.y))
            }
        }
        
        return adjustedPosition
    }
    
    private func getDockPosition(for track: AudioTrack, in size: CGSize) -> CGPoint {
        let dockY = size.height * (1 - dockHeight / 2)
        if let trackIndex = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
            // Calculate position in horizontal scroll using spacing system
            let itemWidth: CGFloat = 56 + AppSpacing.dockItemSpacing // Item size + spacing
            let x = AppSpacing.dockPadding + (itemWidth * CGFloat(trackIndex)) + 28 // Padding + item center
            return CGPoint(x: x, y: dockY)
        }
        return CGPoint(x: size.width / 2, y: dockY)
    }
    
    private func initializeDockPositions() {
        // Initialize all tracks to dock positions
        // This will be done when geometry is available
    }
    
    private func handleDockDrag(trackId: UUID, location: CGPoint, in size: CGSize) {
        draggingTrackId = trackId
        updateOrbFromPosition(trackId: trackId, position: location, in: size)
    }
    
    private func updateOrbFromPosition(trackId: UUID, position: CGPoint, in size: CGSize) {
        // Improved volume calculation with clear zones
        let dockTop = size.height * (1 - dockHeight) // Bottom 10% is dock
        let hubBottom = size.height * 0.15 // Top 15% is hub area
        let activeZoneStart = dockTop // Start of active zone
        let activeZoneEnd = hubBottom // End of active zone
        let activeZoneHeight = activeZoneEnd - activeZoneStart
        
        var volume: Double = 0.0
        var isActive = false
        
        // Check if position is in dock (bottom 10%)
        if position.y >= dockTop {
            // In dock - deactivate
            volume = 0.0
            isActive = false
        } else if position.y < activeZoneEnd {
            // In active zone - calculate volume based on height
            // Higher = louder (closer to hub = louder)
            let distanceFromDock = dockTop - position.y
            if activeZoneHeight > 0 {
                volume = Double(distanceFromDock / activeZoneHeight)
                volume = clamp(volume, min: 0.0, max: 1.0)
            } else {
                volume = 1.0 // If zones overlap, default to max
            }
            
            // Activation threshold: must be at least 2% volume to activate
            isActive = volume > 0.02
            
            // Enhanced haptic feedback at volume milestones (25%, 50%, 75%, 100%)
            let currentMilestone = Int(volume * 4) // 0, 1, 2, 3, 4
            if let index = audioManager.tracks.firstIndex(where: { $0.id == trackId }) {
                let previousVolume = audioManager.tracks[index].volume
                let previousMilestone = Int(previousVolume * 4)
                
                // Only trigger haptic when crossing milestone upward
                if currentMilestone > previousMilestone && currentMilestone > 0 {
                    InstrumentFeedback.threshold(at: currentMilestone >= 3 ? .major : .minor)
                }
            }
        } else {
            // Above active zone (in hub area) - max volume
            volume = 1.0
            isActive = true
        }
        
        // Update track
        if let index = audioManager.tracks.firstIndex(where: { $0.id == trackId }) {
            var updatedTrack = audioManager.tracks[index]
            let wasActive = updatedTrack.isActive
            
            updatedTrack.volume = volume
            updatedTrack.isActive = isActive
            audioManager.tracks[index] = updatedTrack
            
            // Update audio volume (always update for smooth transitions)
            audioManager.updateTrackVolume(trackId, volume: volume)
            
            // Handle state changes
            if isActive && !wasActive {
                // Track was activated (dragged up from dock)
                print("🎵 Activating track: \(updatedTrack.name) at volume: \(Int(volume * 100))%")
                
                // Ensure audio manager is playing
                if !audioManager.isPlaying {
                    audioManager.isPlaying = true
                }
                
                // Ensure volume is at least 1% to trigger playback
                if volume < 0.01 {
                    updatedTrack.volume = 0.01
                    audioManager.tracks[index] = updatedTrack
                }
                
                // Start the track immediately
                audioManager.toggleTrack(trackId, isActive: true)
            } else if !isActive && wasActive {
                // Track was deactivated (dragged back to dock)
                print("⏸️ Deactivating track: \(updatedTrack.name)")
                audioManager.toggleTrack(trackId, isActive: false)
            }
            // If track is already active, volume update is handled above
            
            // Store position
            orbPositions[trackId] = position
        }
    }
    
    private func snapToDockIfNeeded(trackId: UUID, in size: CGSize) {
        guard let position = orbPositions[trackId] else { return }
        let dockTop = size.height * (1 - dockHeight)
        
        // If very close to dock, snap to it
        if position.y > dockTop - 20 {
            if let index = audioManager.tracks.firstIndex(where: { $0.id == trackId }) {
                // Use explicit transaction to avoid animation conflicts
                let transaction = Transaction(animation: .spring(response: 0.3, dampingFraction: 0.7))
                withTransaction(transaction) {
                    // Remove from soundscape positions (will appear in dock)
                    orbPositions.removeValue(forKey: trackId)
                    var updatedTrack = audioManager.tracks[index]
                    updatedTrack.volume = 0.0
                    updatedTrack.isActive = false
                    audioManager.tracks[index] = updatedTrack
                }
                
                // Update audio outside of animation transaction
                audioManager.updateTrackVolume(trackId, volume: 0.0)
                audioManager.toggleTrack(trackId, isActive: false)
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            let fetchedTracks = try await supabaseService.fetchAudioTracks()
            
            // Add frequency tracks
            let frequencyTracks = FrequencyPresetService.shared.createFrequencyTracks()
            
            // Load user recordings if authenticated
            var userRecordings: [AudioTrack] = []
            if let user = authManager.currentUser {
                do {
                    if let accessToken = await authManager.getAccessToken() {
                        userRecordings = try await supabaseService.fetchUserRecordings(
                            accessToken: accessToken,
                            userId: user.id
                        )
                        print("✅ Loaded \(userRecordings.count) user recordings")
                    }
                } catch {
                    print("⚠️ Failed to load user recordings: \(error)")
                }
            }
            
            let allTracks = fetchedTracks + frequencyTracks + userRecordings
            
            await MainActor.run {
                // Only load tracks from Supabase - no fallback to sample tracks
                // If Supabase returns empty, show empty state
                self.audioManager.loadTracks(allTracks)
                print("✅ Loaded \(fetchedTracks.count) tracks from Supabase + \(frequencyTracks.count) frequency tracks + \(userRecordings.count) user recordings")
                
                self.isLoading = false
            }
            
            // Determine which tracks need to play BEFORE loading
            let tracksToPlay = determineTracksToPlay(from: allTracks)
            
            // Preload and start active tracks IMMEDIATELY (non-blocking)
            Task {
                await self.preloadAndStartActiveTracks(tracksToPlay, from: allTracks)
            }
            
            // Start preloading ALL file-based tracks in background for instant response
            // Frequency tracks don't need preloading - they generate in real-time
            // Capture audioManager directly since Soundscape3DView is a struct
            let audioManager = self.audioManager
            Task.detached(priority: .userInitiated) {
                for track in fetchedTracks {
                    // Preload all file-based tracks (non-blocking) - they'll be ready when user taps
                    await MainActor.run {
                        audioManager.preloadTrack(track)
                    }
                }
                print("✅ Started preloading all \(fetchedTracks.count) file-based tracks in background")
            }
            
            // Now restore the full mix state (this will handle any additional tracks)
            await MainActor.run {
                self.restoreLastActiveMix(from: allTracks)
            }
        } catch {
            print("⚠️ Failed to load data from Supabase: \(error)")
            // Don't use fallback - only show tracks from Supabase
            await MainActor.run {
                self.audioManager.loadTracks([]) // Empty array - no tracks if Supabase fails
                self.isLoading = false
            }
        }
    }
    
    // Determine which tracks should play on startup
    // Only reset to Rain if no tracks are currently active (first launch)
    private func determineTracksToPlay(from allTracks: [AudioTrack]) -> [AudioTrack] {
        // Check if there are any active tracks already playing
        let currentlyActiveTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
        
        // If tracks are already active, don't reset - preserve current state
        if !currentlyActiveTracks.isEmpty {
            return [] // Don't reset, keep current tracks
        }
        
        // Only on first launch (no active tracks), use Rain at 50% volume
        if let rainTrack = allTracks.first(where: { $0.name.lowercased().contains("rain") }) {
            var track = rainTrack
            track.isActive = true
            track.volume = 0.5
            return [track]
        }
        
        return []
    }
    
    // Preload and start active tracks immediately
    private func preloadAndStartActiveTracks(_ tracksToPlay: [AudioTrack], from allTracks: [AudioTrack]) async {
        guard !tracksToPlay.isEmpty else { return }
        
        // Preload active tracks first and wait for them to be ready
        for track in tracksToPlay {
            // Preload this track immediately
            await audioManager.preloadTrackImmediately(track)
            
            // Update track state
            if let index = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
                await MainActor.run {
                    self.audioManager.tracks[index].isActive = track.isActive
                    self.audioManager.tracks[index].volume = track.volume
                }
            }
            
            // Start playback immediately (don't wait)
            await MainActor.run {
                if let player = self.audioManager.audioPlayers[track.id] {
                    let targetVolume = Float(track.volume * self.audioManager.masterVolume)
                    player.volume = targetVolume
                    // Use playImmediately for instant start
                    if player.status == .readyToPlay || player.status == .unknown {
                        player.playImmediately(atRate: 1.0)
                    } else {
                        player.play() // Will start when buffer is ready
                    }
                    print("▶️ Started \(track.name) immediately, volume: \(targetVolume)")
                }
            }
        }
        
        // Start audio session playback
        await MainActor.run {
            self.audioManager.play()
            print("🎵 Started \(tracksToPlay.count) active track(s) immediately")
        }
        
        // Lazy load remaining inactive tracks - only preload smart subset
        Task {
            let activeTrackIds = Set(tracksToPlay.map { $0.id })
            let inactiveTracks = allTracks.filter { !activeTrackIds.contains($0.id) }
            
            // Use lazy loader to determine which tracks to preload
            let tracksToPreload = LazyTrackLoader.shared.getTracksToPreload(
                activeTracks: tracksToPlay,
                allTracks: allTracks
            )
            let tracksToPreloadURLs = tracksToPreload
                .filter { !activeTrackIds.contains($0.id) }
                .map { $0.audioUrl }
            
            // Preload smart subset in background with low priority
            await AudioCacheService.shared.preloadTracks(tracksToPreloadURLs, priority: .low)
            
            // Only set up players for tracks that will likely be used
            for track in tracksToPreload.filter({ !activeTrackIds.contains($0.id) }) {
                await MainActor.run {
                    self.audioManager.preloadTrack(track)
                    LazyTrackLoader.shared.markTrackLoaded(track.id)
                }
            }
        }
    }
    
    // MARK: - State Persistence
    
    private func saveCurrentMix() {
        // Save current active tracks
        let activeTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
        StatePersistenceService.shared.saveLastActiveMix(activeTracks)
    }
    
    private func restoreLastActiveMix(from allTracks: [AudioTrack]) {
        // Check if there are already active tracks - if so, don't reset
        let currentlyActiveTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
        if !currentlyActiveTracks.isEmpty {
            // Tracks are already active, preserve them
            return
        }
        
        // Only restore Rain if no tracks are active (first launch)
        if let rainTrack = allTracks.first(where: { $0.name.lowercased().contains("rain") }) {
            if let index = audioManager.tracks.firstIndex(where: { $0.id == rainTrack.id }) {
                audioManager.tracks[index].isActive = true
                audioManager.tracks[index].volume = 0.5
                
                // Ensure player exists and is ready
                if let player = audioManager.audioPlayers[rainTrack.id] {
                    // Player exists, activate it
                    audioManager.toggleTrack(rainTrack.id, isActive: true)
                    audioManager.updateTrackVolume(rainTrack.id, volume: 0.5)
                    
                    // Force play and verify
                    player.volume = Float(0.5 * audioManager.masterVolume)
                    if player.rate == 0 {
                        player.play()
                    }
                    
                    // Verify playback after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if player.rate == 0 {
                            print("⚠️ Rain not playing, forcing play...")
                            player.play()
                        } else {
                            print("✅ Rain confirmed playing: rate=\(player.rate), volume=\(player.volume)")
                        }
                    }
                } else {
                    // Player not ready yet, use toggleTrack which will wait
                    audioManager.toggleTrack(rainTrack.id, isActive: true)
                    audioManager.updateTrackVolume(rainTrack.id, volume: 0.5)
                    
                    // Wait for player and verify
                    Task {
                        var attempts = 0
                        while audioManager.audioPlayers[rainTrack.id] == nil && attempts < 20 {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                            attempts += 1
                        }
                        
                        if let player = audioManager.audioPlayers[rainTrack.id] {
                            await MainActor.run {
                                player.volume = Float(0.5 * audioManager.masterVolume)
                                if player.rate == 0 {
                                    player.play()
                                }
                            }
                        }
                    }
                }
                
                audioManager.play()
                print("🌧️ Activated Rain at 50% volume (always single track on launch)")
                
                // Mark as launched if first time
                if StatePersistenceService.shared.isFirstLaunch() {
                    StatePersistenceService.shared.markLaunched()
                }
            } else {
                print("⚠️ Rain track not found in audioManager.tracks")
            }
        } else {
            print("⚠️ Rain track not found in allTracks")
        }
    }
}

// ──────────────────────────────────────────────────────────────
// Phase 3.2 — Dead-code purge.
//
// The following structs were defined but had no live caller in the
// Studio body. They survived only as compiled symbols and a slow
// drag on debug builds. The active Studio is composed entirely from
// ImmersiveBackground + DynamicColorOrb + GridSoundItem +
// ActiveMixDock + DockSoundChip + SoundControlModal +
// MasterVolumeSlider, all retained below.
//
//   - PullableSoundOrb (dragable orb mechanic, never instantiated)
//   - SoundDock + DockSoundItem (older dock implementation)
//   - WaveformRings (only consumed by PullableSoundOrb)
//   - ParticleSystem + Particle (Timer-driven physics overlay,
//     never instantiated; pure performance liability)
//
// Removing them takes Soundscape3DView from ~3,200 to ~2,550 lines
// and removes three Timer-based hot paths. No behavior change.
// ──────────────────────────────────────────────────────────────

// MARK: - Enhanced Dynamic Immersive Background
struct ImmersiveBackground: View {
    let activeTracks: [AudioTrack]
    @State private var colorOrbs: [ColorOrb] = []
    @State private var animationTimer: Timer?
    @ObservedObject private var featureFlags = AmbientFeatureFlags.shared
    @EnvironmentObject private var composition: CompositionSession

    struct ColorOrb: Identifiable {
        let id = UUID()
        var position: CGPoint
        var size: CGFloat
        var color: Color
        var opacity: Double
        var pulsePhase: Double = 0
        var velocity: CGSize = .zero
    }

    /// Resolved background video for the current composition, gated by
    /// the Low Power feature flag. When non-nil we render the player as
    /// the bottommost layer and pull every procedural wash above it
    /// down a notch so the room reads as "this video, dressed."
    private var backgroundVideoURL: URL? {
        guard featureFlags.allowBackgroundVideo else { return nil }
        return composition.resolvedVideoURL(in: activeTracks)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Bottom layer: muted, looped, blurred composition video
                // when one has been chosen. Drives the room's "this is the
                // place" cue; everything else layers on top with reduced
                // opacity so the scene reads through the chrome.
                if let videoURL = backgroundVideoURL {
                    RoomBackgroundPlayer(url: videoURL)
                        .ignoresSafeArea(.all)
                        .transition(.opacity)
                }

                // Enhanced base gradient - edge-to-edge, extends fully.
                // When the video layer is showing, drop the gradient's
                // opacity so the scene shows through rather than being
                // covered up by the deep-space wash.
                AppTheme.background
                    .ignoresSafeArea(.all)
                    .opacity(backgroundVideoURL == nil ? 1.0 : 0.4)
                    .animation(Motion.cinema, value: backgroundVideoURL)
                
                // Liquid Glass Layer 1: Content-driven color gradient
                if !activeTracks.isEmpty {
                    let trackNames = activeTracks.map { $0.name }
                    AppTheme.contentGradient(for: trackNames)
                        .opacity(0.3)
                        .blendMode(.plusLighter)
                        .ignoresSafeArea(.all)
                }
                
                // Liquid Glass Layer 2: Dynamic color wash from active sounds (enhanced)
                if !activeTracks.isEmpty {
                    ForEach(activeTracks, id: \.id) { track in
                        let color = SoundColor.colorForTrack(track.name)
                        // Enhanced opacity for Liquid Glass - colors bleed through controls
                        let opacity = 0.12 * track.volume
                        color
                            .opacity(opacity)
                            .blendMode(.plusLighter)
                            .animation(AppTheme.Animation.fluid, value: track.volume)
                            .ignoresSafeArea(.all)
                    }
                }
                
                // Floating color orbs (3-5 orbs) — gated by Low Power Mode
                if featureFlags.allowFloatingColorOrbs {
                    ForEach(colorOrbs) { orb in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        orb.color.opacity(orb.opacity),
                                        orb.color.opacity(orb.opacity * 0.5),
                                        orb.color.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: orb.size * 0.3,
                                    endRadius: orb.size
                                )
                            )
                            .frame(width: orb.size, height: orb.size)
                            .position(orb.position)
                            .blur(radius: orb.size * 0.2)
                            .scaleEffect(1.0 + sin(orb.pulsePhase) * 0.2)
                    }
                }
                
                // Active sound color orbs (pulsing with volume).
                //
                // Position is derived deterministically from `track.id` so the
                // orbs do not jump to a new spot every time the body re-renders
                // (e.g. when a track's volume changes). Previously this used
                // `Double.random(in:)` inside the body, which produced visible
                // flicker on every tracker update.
                ForEach(activeTracks, id: \.id) { track in
                    let color = SoundColor.colorForTrack(track.name)
                    let offset = Self.stablePositionOffset(for: track.id)
                    DynamicColorOrb(
                        color: color,
                        volume: track.volume,
                        position: CGPoint(
                            x: geometry.size.width * (0.2 + 0.6 * offset.x),
                            y: geometry.size.height * (0.2 + 0.6 * offset.y)
                        )
                    )
                }
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            // Safely initialize background
            generateColorOrbs()
            startOrbAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
        .onChange(of: activeTracks.count) { oldCount, newCount in
            // Only update if count actually changed
            if oldCount != newCount {
                updateOrbsForActiveTracks()
            }
        }
    }

    /// Maps a track id to a stable point in [0, 1) × [0, 1) so each active
    /// track always lights up the same region of the scene. Splits the
    /// UUID into two 64-bit halves and normalizes each to a Double.
    private static func stablePositionOffset(for id: UUID) -> (x: Double, y: Double) {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let hi = bytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let lo = bytes.suffix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let x = Double(hi) / Double(UInt64.max)
        let y = Double(lo) / Double(UInt64.max)
        return (x, y)
    }
    
    private func generateColorOrbs() {
        // Generate 3-5 floating orbs - ensure safe initialization
        let count = max(3, min(5, Int.random(in: 3...5)))
        let availableColors: [Color] = [
            SoundColor.rain,
            SoundColor.ocean,
            SoundColor.thunder,
            SoundColor.fireplace,
            SoundColor.meditation
        ]
        
        colorOrbs = (0..<count).map { _ in
            ColorOrb(
                position: CGPoint(
                    x: CGFloat.random(in: 100...800),
                    y: CGFloat.random(in: 100...1200)
                ),
                size: CGFloat.random(in: 300...600),
                color: availableColors.randomElement() ?? SoundColor.rain,
                opacity: Double.random(in: 0.1...0.3)
            )
        }
    }
    
    private func startOrbAnimation() {
        // 5x slower, very relaxed animation - update every 0.25 seconds instead of 0.05
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            updateOrbs()
        }
    }
    
    private func updateOrbs() {
        for index in colorOrbs.indices {
            // Slow drift movement
            colorOrbs[index].position.x += colorOrbs[index].velocity.width
            colorOrbs[index].position.y += colorOrbs[index].velocity.height
            
            // 5x slower pulse phase update for very relaxed animation
            colorOrbs[index].pulsePhase += 0.004
            
            // Very gentle velocity changes
            colorOrbs[index].velocity.width += CGFloat.random(in: -0.01...0.01)
            colorOrbs[index].velocity.height += CGFloat.random(in: -0.01...0.01)
            
            // Clamp velocity (much slower max velocity)
            colorOrbs[index].velocity.width = clamp(colorOrbs[index].velocity.width, min: -0.2, max: 0.2)
            colorOrbs[index].velocity.height = clamp(colorOrbs[index].velocity.height, min: -0.2, max: 0.2)
        }
    }
    
    private func updateOrbsForActiveTracks() {
        // Adjust orb colors/intensity based on active tracks
        let activeTracksFiltered = activeTracks.filter { $0.isActive && $0.volume > 0 }
        if !activeTracksFiltered.isEmpty {
            for index in colorOrbs.indices {
                if let activeTrack = activeTracksFiltered.randomElement() {
                    colorOrbs[index].color = SoundColor.colorForTrack(activeTrack.name)
                    colorOrbs[index].opacity = min(0.4, Double(activeTrack.volume) * 0.3)
                }
            }
        }
    }
}

// MARK: - Dynamic Color Orb (for active sounds)
//
// Constellation drift (Phase 3.5).
//
// Each per-track DynamicColorOrb anchors to a stable point on the
// scene (the parent supplies it from the track's UUID) and now drifts
// gently around that anchor — ±14pt over an asymmetric 28s/34s sin/cos
// pair, so the orbs look like a constellation breathing rather than a
// metronome. The drift is driven by a TimelineView running at .animation
// granularity so it costs zero ObservedObject churn and never wakes
// the run loop more than the display does.
//
// Drift is gated by AmbientFeatureFlags.allowFloatingColorOrbs (already
// gating whether we render at all) plus the environment Reduce Motion
// flag. With Reduce Motion on, each orb sits perfectly still on its
// anchor — same composition, just no sway.
struct DynamicColorOrb: View {
    let color: Color
    let volume: Double
    let position: CGPoint

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 1.0

    /// Stable per-orb seed so two orbs at slightly different anchors
    /// drift on completely unrelated phases. Hashing the position
    /// avoids needing a new parameter on every caller.
    private var seed: Double {
        let s = sin(Double(position.x) * 12.9898 + Double(position.y) * 78.233) * 43758.5453
        return s - floor(s)               // [0, 1)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            // Two orthogonal sin curves with prime-ish periods so the
            // path never repeats visibly. Amplitude scaled by volume:
            // a faint orb drifts subtly, a loud one sways more.
            let amplitude: Double = 14.0 * (0.6 + volume * 0.4)
            let driftX = amplitude * sin((t / 28.0 + seed) * 2 * .pi)
            let driftY = amplitude * cos((t / 34.0 + seed * 1.7) * 2 * .pi)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.15 * volume),
                            color.opacity(0.08 * volume),
                            color.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 400 * CGFloat(volume)
                    )
                )
                .frame(width: 800 * CGFloat(volume), height: 800 * CGFloat(volume))
                .position(x: position.x + CGFloat(driftX), y: position.y + CGFloat(driftY))
                .blur(radius: 100 * CGFloat(volume))
                .scaleEffect(pulseScale)
        }
        .onAppear {
            // Long, calm volume pulse. Reduce Motion users get a
            // static scale of 1.0 which is the initial value, so
            // skipping the animation here matches that intent.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 20.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.03
            }
        }
    }
}

// MARK: - Grid Sound Item with Tap and Long Press
struct GridSoundItem: View {
    @Binding var track: AudioTrack
    @ObservedObject var audioManager: AudioManager
    @Binding var soundsInVolumeMode: Set<UUID> // Binding to parent to disable scrolling
    @Binding var isDraggingToDock: Set<UUID> // Binding to track dragging state
    let dockFrame: CGRect // Dock frame for drop detection
    let itemPosition: CGPoint // Item's current position in global coordinates
    let onLongPress: () -> Void // Callback for long press to open modal
    
    @State private var isPressed = false
    @State private var isVolumeMode = false
    @State private var rotationAngle: Double = 0
    @State private var lastRotationAngle: Double = 0
    @State private var isDragging = false
    @State private var isDraggingToDockLocal = false // Local state for this item
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartPosition: CGPoint = .zero // Track item position when drag started
    @State private var currentGlobalCenter: CGPoint = .zero // Track current center in global coordinates
    @State private var lastVolumeUpdateTime: Date = Date()
    private let volumeUpdateThrottle: TimeInterval = 0.05 // Update volume max every 50ms
    
    private var trackColor: Color {
        SoundColor.colorForTrack(track.name)
    }
    
    private var isActive: Bool {
        track.isActive && track.volume > 0
    }
    
    // Constants for sound orb sizing - smaller for 4-column grid
    private var baseSize: CGFloat { 70 } // Smaller size for 4 columns
    private var volumeModeSize: CGFloat { 90 } // Larger when in volume mode
    private var cornerRadius: CGFloat { 16 } // More rounded for premium feel
    
    // Background glow helper - subtle white glow
    private var backgroundGlow: some View {
        RoundedRectangle(cornerRadius: cornerRadius + 8)
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.2 * Double(track.volume)),
                        Color.white.opacity(0.1 * Double(track.volume)),
                        Color.white.opacity(0.05 * Double(track.volume)),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: baseSize * 0.7
                )
            )
            .frame(width: isVolumeMode ? volumeModeSize + 30 : baseSize + 20, 
                   height: isVolumeMode ? volumeModeSize + 30 : baseSize + 20)
            .blur(radius: 20)
    }
    
    // Border gradient helper
    private var borderGradient: LinearGradient {
        let activeColors = [
            trackColor.opacity(0.8),
            trackColor.opacity(0.5),
            trackColor.opacity(0.3),
            trackColor.opacity(0.5),
            trackColor.opacity(0.8)
        ]
        let inactiveColors = [
            Color.white.opacity(0.25),
            Color.white.opacity(0.15),
            Color.white.opacity(0.1),
            Color.white.opacity(0.15),
            Color.white.opacity(0.25)
        ]
        return LinearGradient(
            colors: isActive ? activeColors : inactiveColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Main glass card view - see-through white liquid glass
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .opacity(0.4) // More see-through
            .overlay(
                // White tint overlay for see-through white effect
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(secondaryMaterialLayer)
            .overlay(borderStroke)
            .overlay(orbHighlight)
            .frame(width: isVolumeMode ? volumeModeSize : baseSize, 
                   height: isVolumeMode ? volumeModeSize : baseSize)
            .shadow(color: Color.white.opacity(isActive ? 0.3 : 0.1), 
                   radius: isActive ? 12 : 4,
                   x: 0, y: isActive ? 4 : 2)
            .shadow(color: Color.black.opacity(0.05), 
                   radius: isActive ? 6 : 2,
                   x: 0, y: isActive ? 2 : 1)
            .scaleEffect(isPressed ? 0.96 : (isDraggingToDockLocal ? 1.1 : 1.0))
            .opacity(isDraggingToDockLocal ? 0.8 : 1.0)
            .overlay(orbIcon)
            .overlay(orbPulseRing)
    }
    
    // Secondary material layer - white tint
    private var secondaryMaterialLayer: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    // Border stroke - see-through white
    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isActive ? 2.0 : 1.5
            )
    }
    
    // Volume dial view
    private var volumeDial: some View {
        ZStack {
            volumeArc
            volumeIndicator
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(nil, value: rotationAngle)
    }
    
    private var soundOrb: some View {
        ZStack {
            // Background glow when active
            if isActive {
                backgroundGlow
            }
            
            // Liquid Glass rounded rectangle
            ZStack {
                glassCard
                
                // Volume dial (rotates independently around the icon)
                if isVolumeMode {
                    volumeDial
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .animation(isDragging ? nil : AppTheme.Animation.liquidSpring, value: isVolumeMode)
        .animation(nil, value: rotationAngle)
    }
    
    private var orbBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: isActive ? [
                        trackColor.opacity(0.6),
                        trackColor.opacity(0.3)
                    ] : [
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isActive ? 2 : 1
            )
    }
    
    private var orbHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isActive ? 0.4 : 0.2),
                        Color.white.opacity(isActive ? 0.2 : 0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
    }
    
    private var orbIcon: some View {
        let iconSize: CGFloat = isVolumeMode ? 32 : 28 // Smaller icons for smaller elements
        
        return Image(systemName: track.icon)
            .font(.system(size: iconSize, weight: .semibold, design: .rounded))
            .foregroundStyle(
                // Clean white icon styling
                LinearGradient(
                    colors: isActive ? [
                        Color.white.opacity(0.95), // Premium white
                        Color.white.opacity(0.85)
                    ] : [
                        Color.white.opacity(0.8),
                        Color.white.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(isActive && !isVolumeMode ? (1.0 + sin(Date().timeIntervalSince1970 * 1.0) * 0.03) : 1.0) // Subtle, slow pulsation when active
            .animation(isActive && !isVolumeMode ? .easeInOut(duration: 2.5).repeatForever(autoreverses: true) : .default, value: isActive)
    }
    
    private var orbPulseRing: some View {
        Group {
            if isActive && !isVolumeMode {
                // Sound ring for selected state - more visible and properly sized
                RoundedRectangle(cornerRadius: cornerRadius + 2)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.0
                    )
                    .frame(width: baseSize + 4, height: baseSize + 4) // Slightly larger than base tile
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 1.5) * 0.08) // Slower, subtler pulse
            }
        }
    }
    
    private var volumeArc: some View {
        Group {
            if isVolumeMode {
                // Volume indicator for rounded rectangles - using overlay border, white theme
                RoundedRectangle(cornerRadius: cornerRadius + 2)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8 * Double(track.volume)),
                                Color.white.opacity(0.4 * Double(track.volume))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: volumeModeSize + 4, height: volumeModeSize + 4)
                    .opacity(track.volume > 0 ? 1 : 0)
                    .animation(nil, value: track.volume)
            }
        }
    }
    
    private var volumeIndicator: some View {
        Group {
            if isVolumeMode {
                // Indicator dot at top of rounded rectangle - white theme
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .offset(y: -(volumeModeSize / 2 + 2))
                    .shadow(color: Color.white.opacity(0.6), radius: 3)
            }
        }
    }

    /// Dock-drag arms only after this hold so scrolling the grid doesn't grab tiles.
    private let dockDragLongPressDuration: Double = 0.5
    /// Finger jitter budget while waiting — scrolling exceeds this and cancels the long press.
    private let dockDragLongPressMaxDistance: CGFloat = 14
    /// After the half-second hold, a tile only "commits" to dock-drag once the finger moves this far.
    private let dockDragMovementCommitPoints: CGFloat = 10

    private var dragInactiveTrackToDockGesture: some Gesture {
        LongPressGesture(minimumDuration: dockDragLongPressDuration, maximumDistance: dockDragLongPressMaxDistance)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard !isVolumeMode, !isActive else { return }
                switch value {
                case .second(true, let dragState):
                    guard let drag = dragState else { return }
                    let t = drag.translation
                    if !isDraggingToDockLocal {
                        guard hypot(t.width, t.height) >= dockDragMovementCommitPoints else { return }
                        isDraggingToDockLocal = true
                        isPressed = true
                        dragStartPosition = itemPosition
                        currentGlobalCenter = itemPosition
                        isDraggingToDock.insert(track.id)
                        InstrumentFeedback.dragStart()
                    }
                    dragOffset = t
                default:
                    break
                }
            }
            .onEnded { value in
                guard !isVolumeMode, !isActive else { return }
                switch value {
                case .second(true, let dragState):
                    guard let drag = dragState else {
                        cancelInactiveDockDragAnimation()
                        return
                    }
                    finishInactiveDockDrag(drag: drag)
                default:
                    cancelInactiveDockDragAnimation()
                }
            }
    }

    private func cancelInactiveDockDragAnimation() {
        isPressed = false
        let wasDragging = isDraggingToDockLocal
        isDraggingToDockLocal = false
        isDraggingToDock.remove(track.id)
        if wasDragging {
            InstrumentFeedback.dragEnd()
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
    }

    private func finishInactiveDockDrag(drag: DragGesture.Value) {
        isPressed = false
        let wasDraggingToDock = isDraggingToDockLocal
        isDraggingToDockLocal = false
        isDraggingToDock.remove(track.id)

        let dropPosition = CGPoint(
            x: dragStartPosition.x + drag.translation.width,
            y: dragStartPosition.y + drag.translation.height
        )

        let expandedDockFrame = dockFrame.isEmpty ? .zero : CGRect(
            x: dockFrame.minX - 20,
            y: dockFrame.minY - 20,
            width: dockFrame.width + 40,
            height: dockFrame.height + 40
        )

        if wasDraggingToDock {
            print("🎯 Drop detection - Track: \(track.name)")
            print("   Drag start position: \(dragStartPosition)")
            print("   Translation: \(drag.translation)")
            print("   Calculated drop position: \(dropPosition)")
            print("   Dock frame: \(dockFrame)")
            print("   Expanded frame: \(expandedDockFrame)")
            print("   Dock Y range: \(expandedDockFrame.minY) to \(expandedDockFrame.maxY)")
            print("   Drop Y: \(dropPosition.y)")
            print("   Y in range: \(dropPosition.y >= expandedDockFrame.minY && dropPosition.y <= expandedDockFrame.maxY)")
            print("   X in range: \(dropPosition.x >= expandedDockFrame.minX && dropPosition.x <= expandedDockFrame.maxX)")
            print("   Contains drop: \(expandedDockFrame.contains(dropPosition))")
        }

        let screenBottom: CGFloat = 800
        let bottomAreaThreshold: CGFloat = 200
        let isInBottomArea = dropPosition.y > (screenBottom - bottomAreaThreshold)

        if wasDraggingToDock && isInBottomArea {
            print("✅ Dropped in bottom area - treating as dock drop!")
        }

        let droppedInDock = !dockFrame.isEmpty && expandedDockFrame.contains(dropPosition)
        let droppedInBottomArea = isInBottomArea

        if wasDraggingToDock && (droppedInDock || droppedInBottomArea) {
            print("✅ Dropped \(track.name) into dock!")
            let relativeX = dropPosition.x - dockFrame.minX
            let dockWidth = dockFrame.width
            let positionRatio = max(0, min(1, relativeX / dockWidth))

            let volume: Double
            if positionRatio < 0.33 {
                volume = 0.20
            } else if positionRatio < 0.67 {
                volume = 0.50
            } else {
                volume = 0.85
            }

            InstrumentFeedback.dragEnd()

            if let index = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
                var updatedTrack = audioManager.tracks[index]
                let wasActive = updatedTrack.isActive

                updatedTrack.isActive = true
                updatedTrack.volume = volume
                audioManager.tracks[index] = updatedTrack

                audioManager.updateTrackVolume(track.id, volume: volume)

                if !wasActive {
                    audioManager.toggleTrack(track.id, isActive: true)
                }

                if let player = audioManager.audioPlayers[track.id], player.rate == 0 {
                    player.play()
                }
            }
        } else if wasDraggingToDock {
            InstrumentFeedback.dragEnd()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
    }

    var body: some View {
        // Label underneath the tile
        VStack(spacing: 6) {
            soundOrb
            
            // Track name underneath - small label
            Text(track.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 14) // Fixed height for consistent spacing
                .allowsHitTesting(false) // Don't interfere with tile interactions
        }
        .contentShape(Rectangle())
        .offset(dragOffset)
        .background(
            GeometryReader { itemGeometry in
                let globalFrame = itemGeometry.frame(in: .global)
                let globalCenter = globalFrame.center
                
                Color.clear
                    .preference(
                        key: GridItemPositionPreferenceKey.self,
                        value: [track.id: globalCenter]
                    )
                    .onChange(of: dragOffset) { _, _ in
                        // Update current global center when drag offset changes
                        // The frame includes the offset, so this gives us the dragged position
                        currentGlobalCenter = globalCenter
                    }
                    .onAppear {
                        currentGlobalCenter = globalCenter
                    }
                    .onChange(of: globalFrame) { _, _ in
                        // Also update when frame changes (which happens as offset changes)
                        currentGlobalCenter = globalCenter
                    }
            }
        )
        // NOTE: A second `.onTapGesture` was previously defined later in this
        // view's modifier chain. In SwiftUI only one `.onTapGesture` ultimately
        // recognizes the tap (the last-applied one wins), so the earlier
        // handler was dead code. It was removed in Phase 1.4; the canonical
        // toggle/volume-mode-exit logic lives in the single `.onTapGesture`
        // further below.
        // Dock drag runs simultaneous with scroll and only arms after a half-second hold,
        // so swiping the grid doesn't instantly pick up a tile.
        .simultaneousGesture(!isVolumeMode && !isActive ? dragInactiveTrackToDockGesture : nil)
        .simultaneousGesture(
            // Rotation gesture for volume control (only active in volume mode)
            isVolumeMode ? DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        InstrumentFeedback.dragStart()
                    }
                    
                    // Calculate angle from center
                    // When in volume mode, orb is 120x120, so center is 60,60
                    // We need to get the actual center of the orb in the view
                    let orbSize: CGFloat = isVolumeMode ? 120 : 100
                    let center = CGPoint(x: orbSize / 2, y: orbSize / 2)
                    let currentAngle = atan2(value.location.y - center.y, value.location.x - center.x)
                    
                    // Convert to degrees (-180 to 180)
                    var currentDegrees = currentAngle * 180 / .pi
                    
                    // Normalize to 0-360 range
                    if currentDegrees < 0 {
                        currentDegrees += 360
                    }
                    
                    // Convert to -180 to 180 for rotation calculation
                    var normalizedCurrent = currentDegrees
                    if normalizedCurrent > 180 {
                        normalizedCurrent -= 360
                    }
                    
                    // Calculate delta from last position
                    var delta = normalizedCurrent - lastRotationAngle
                    
                    // Handle wrap-around (crossing 180/-180 boundary)
                    if abs(delta) > 180 {
                        if delta > 0 {
                            delta -= 360
                        } else {
                            delta += 360
                        }
                    }
                    
                    // Update rotation angle directly (no animation to avoid conflicts)
                    // Use Transaction to explicitly disable animations
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    
                    var newAngle = rotationAngle + delta
                    
                    // Clamp rotation angle (-180 to +180)
                    newAngle = max(-180, min(180, newAngle))
                    
                    // Update without triggering animations
                    withTransaction(transaction) {
                        rotationAngle = newAngle
                    }
                    
                    // Convert rotation to volume
                    // rotationAngle: -180 (min) to +180 (max)
                    // volume: 0.0 to 1.0
                    let newVolume = (rotationAngle + 180) / 360
                    let clampedVolume = max(0.0, min(1.0, newVolume))
                    
                    // Throttle volume updates to avoid excessive calls
                    let now = Date()
                    let timeSinceLastUpdate = now.timeIntervalSince(lastVolumeUpdateTime)
                    
                    // Only update if enough time has passed or volume changed significantly (>2%)
                    let volumeDelta = abs(clampedVolume - track.volume)
                    if timeSinceLastUpdate >= volumeUpdateThrottle || volumeDelta > 0.02 {
                        // Update volume with haptic feedback at milestones
                        let oldMilestone = Int(track.volume * 4)
                        let newMilestone = Int(clampedVolume * 4)
                        
                        if newMilestone != oldMilestone && newMilestone >= 0 && newMilestone <= 4 {
                            InstrumentFeedback.threshold(at: (newMilestone == 0 || newMilestone == 4) ? .major : .minor)
                        }
                        
                        // Update track volume
                        if let index = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
                            audioManager.tracks[index].volume = clampedVolume
                            audioManager.updateTrackVolume(track.id, volume: clampedVolume)
                            
                            // Save mix state after volume change (throttled)
                            if timeSinceLastUpdate >= volumeUpdateThrottle {
                                let activeTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
                                StatePersistenceService.shared.saveLastActiveMix(activeTracks)
                            }
                        }
                        
                        lastVolumeUpdateTime = now
                    }
                    
                    lastRotationAngle = normalizedCurrent
                }
                .onEnded { _ in
                    isDragging = false
                    
                    // Exit volume mode after a brief delay to show final volume state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // Only exit if we're still in volume mode and not dragging again
                        if isVolumeMode && !isDragging {
                            withAnimation(AppTheme.Animation.spring) {
                                isVolumeMode = false
                            }
                            // Notify parent to re-enable scrolling
                            soundsInVolumeMode.remove(track.id)
                        }
                    }
                }
            : nil
        )
        .onTapGesture {
            // Suppress tap while a drag-to-dock gesture is in flight.
            guard !isDraggingToDockLocal else { return }

            // If in volume mode, exit volume mode
            if isVolumeMode {
                isDragging = false
                // Don't reset rotation angle - keep it so volume dial position is preserved visually
                // Exit volume mode with spring animation (size will animate back to normal)
                withAnimation(AppTheme.Animation.spring) {
                    isVolumeMode = false
                }
                // Notify parent to re-enable scrolling (if no other sounds are in volume mode)
                soundsInVolumeMode.remove(track.id)
                return
            }
            
            // Otherwise, toggle track on/off
            
            // Toggle track on/off
            let newState = !isActive
            
            print("🎵 Toggling track: \(track.name) to \(newState ? "ON" : "OFF")")
            
            InstrumentFeedback.toggle(active: newState)
            
            // Update track state
            if let index = audioManager.tracks.firstIndex(where: { $0.id == track.id }) {
                let currentTrack = audioManager.tracks[index]
                var updatedTrack = currentTrack
                
                // Calculate new volume
                if newState {
                    // Turn on - set to 50% volume if was off
                    if updatedTrack.volume == 0 {
                        updatedTrack.volume = 0.5
                    }
                    print("🔊 Setting volume to: \(Int(updatedTrack.volume * 100))%")
                } else {
                    // Turn off
                    updatedTrack.volume = 0.0
                }
                
                // Toggle track FIRST (before updating array) - this handles play/pause correctly
                // toggleTrack checks the current state in the array, so we must call it before updating
                audioManager.toggleTrack(track.id, isActive: newState)
                
                // Now update the array state
                updatedTrack.isActive = newState
                audioManager.tracks[index] = updatedTrack
                
                // Then update volume - this ensures volume is set correctly without restarting playback
                audioManager.updateTrackVolume(track.id, volume: updatedTrack.volume)
                
                // Save mix state after user interaction
                let activeTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
                StatePersistenceService.shared.saveLastActiveMix(activeTracks)
                
                // Verify playback after a short delay
                if newState {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let player = audioManager.audioPlayers[track.id] {
                            if player.rate == 0 {
                                print("⚠️ Player not playing after toggle, forcing play...")
                                player.play()
                            } else {
                                print("✅ Player is playing: \(track.name), rate: \(player.rate), volume: \(player.volume)")
                            }
                        } else {
                            print("⚠️ Player not found for track: \(track.name)")
                        }
                    }
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.95) {
            // Longer hold than dock-drag (0.5s hold + small move) so mixing a sound
            // doesn't open the aperture modal by accident.
            guard !isDraggingToDockLocal, !isVolumeMode else { return }
            InstrumentFeedback.preset(applied: track.name)
            onLongPress()
        }
        .onChange(of: isVolumeMode) { _, showing in
            if !showing {
                isDragging = false
            }
        }
        .onChange(of: soundsInVolumeMode.contains(track.id)) { _, shouldBeInVolumeMode in
            // Automatically enter volume mode if track ID is in the set
            if shouldBeInVolumeMode && !isVolumeMode {
                // Initialize rotation angle based on current volume
                let initialAngle = (track.volume * 360) - 180
                rotationAngle = initialAngle
                lastRotationAngle = initialAngle
                
                withAnimation(AppTheme.Animation.spring) {
                    isVolumeMode = true
                }
            } else if !shouldBeInVolumeMode && isVolumeMode {
                // Exit volume mode if removed from set
                isDragging = false
                withAnimation(nil) {
                    rotationAngle = 0
                }
                withAnimation(AppTheme.Animation.spring) {
                    isVolumeMode = false
                }
            }
        }
    }
}


// MARK: - Active Mix Dock
struct ActiveMixDock: View {
    let activeTracks: [AudioTrack]
    @ObservedObject var audioManager: AudioManager
    @Binding var soundsInVolumeMode: Set<UUID>
    @Binding var selectedTrackForModal: AudioTrack? // Shared with parent for modal state
    let screenHeight: CGFloat // Full screen height for volume control range
    let bottomSafeArea: CGFloat // Bottom safe area padding
    let dockWidth: CGFloat? // Optional width to match grid (3 tiles width)
    let onDockFrameChange: ((CGRect) -> Void)? // Callback to report dock frame
    
    @State private var dockAnchors: [UUID: CGPoint] = [:] // Track element anchor points in global coordinates
    
    init(activeTracks: [AudioTrack], 
         audioManager: AudioManager, 
         soundsInVolumeMode: Binding<Set<UUID>>, 
         selectedTrackForModal: Binding<AudioTrack?>, 
         screenHeight: CGFloat, 
         bottomSafeArea: CGFloat,
         dockWidth: CGFloat? = nil,
         onDockFrameChange: ((CGRect) -> Void)? = nil) {
        self.activeTracks = activeTracks
        self.audioManager = audioManager
        self._soundsInVolumeMode = soundsInVolumeMode
        self._selectedTrackForModal = selectedTrackForModal
        self.screenHeight = screenHeight
        self.bottomSafeArea = bottomSafeArea
        self.dockWidth = dockWidth
        self.onDockFrameChange = onDockFrameChange
    }
    
    var body: some View {
        // When dockWidth is provided (grid mode), render directly without GeometryReader
        // This prevents double rendering - the parent already handles positioning
        if let dockWidth = dockWidth {
            // Grid mode: Simple dock content - parent handles positioning and centering
            ZStack {
                // Full-screen overlay for volume-mode elements
                ForEach(activeTracks, id: \.id) { track in
                    if soundsInVolumeMode.contains(track.id), let anchor = dockAnchors[track.id] {
                        DockSoundChip(
                            track: track,
                            audioManager: audioManager,
                            soundsInVolumeMode: $soundsInVolumeMode,
                            availableHeight: screenHeight,
                            isOverlay: true,
                            dockAnchor: anchor,
                            onTap: {
                                selectedTrackForModal = track
                            }
                        )
                        .position(x: anchor.x, y: anchor.y)
                        .zIndex(1000)
                        .allowsHitTesting(true)
                        .drawingGroup()
                    }
                }
                
                // Dock content - only show when modal is closed, centered
                if selectedTrackForModal == nil {
                    dockContentBody(width: dockWidth)
                        .frame(maxWidth: dockWidth) // Ensure proper width constraint
                }
            }
            .frame(maxWidth: .infinity) // Allow parent to center
            .onPreferenceChange(DockElementPositionPreferenceKey.self) { anchors in
                for (id, anchor) in anchors {
                    dockAnchors[id] = anchor
                }
            }
        } else {
            // Focus mode: Need GeometryReader for full-screen overlay positioning
            GeometryReader { geometry in
                ZStack {
                    // Full-screen overlay for volume-mode elements
                    ForEach(activeTracks, id: \.id) { track in
                        if soundsInVolumeMode.contains(track.id), let anchor = dockAnchors[track.id] {
                            DockSoundChip(
                                track: track,
                                audioManager: audioManager,
                                soundsInVolumeMode: $soundsInVolumeMode,
                                availableHeight: screenHeight,
                                isOverlay: true,
                                dockAnchor: anchor,
                                onTap: {
                                    selectedTrackForModal = track
                                }
                            )
                            .position(x: anchor.x, y: anchor.y)
                            .zIndex(1000)
                            .allowsHitTesting(true)
                            .drawingGroup()
                        }
                    }
                    
                    // Focus mode: iOS-style dock at very bottom
                    if selectedTrackForModal == nil {
                        VStack {
                            Spacer()
                            
                            // iOS-style dock - full width with small padding, at very bottom
                            dockContentBody(width: geometry.size.width - (AppSpacing.md * 2))
                                .padding(.horizontal, AppSpacing.md) // Small horizontal padding like iOS
                                .padding(.bottom, max(bottomSafeArea - 0, 0)) // Position lower, closer to bottom edge
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onPreferenceChange(DockElementPositionPreferenceKey.self) { anchors in
                    for (id, anchor) in anchors {
                        dockAnchors[id] = anchor
                    }
                }
            }
        }
    }
    
    // iOS-style dock content - always shown on grid screen
    @ViewBuilder
    private func dockContentBody(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Horizontal scrolling dock with iOS-style background
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.lg) { // Generous spacing like iOS dock
                    ForEach(activeTracks, id: \.id) { track in
                        DockSoundChip(
                            track: track,
                            audioManager: audioManager,
                            soundsInVolumeMode: $soundsInVolumeMode,
                            availableHeight: screenHeight,
                            isOverlay: false,
                            dockAnchor: nil,
                            onTap: {
                                selectedTrackForModal = track
                            }
                        )
                        .background(
                            GeometryReader { chipGeometry in
                                Color.clear
                                    .preference(
                                        key: DockElementPositionPreferenceKey.self,
                                        value: [track.id: chipGeometry.frame(in: .global).center]
                                    )
                            }
                        )
                        .opacity(soundsInVolumeMode.contains(track.id) ? 0 : 1) // Hide when in overlay
                    }
                }
                .padding(.horizontal, AppSpacing.lg) // iOS-style padding
                .padding(.vertical, AppSpacing.md) // iOS-style vertical padding
            }
            .scrollDisabled(!soundsInVolumeMode.isEmpty)
        }
        .frame(width: width)
        // Aurora dock chrome (Phase 3.2). The v1 dock leaned on raw
        // ultraThinMaterial with a 1pt white-opacity stroke. The Aurora
        // dock vocabulary adds a hairline AuroraColors.Stroke.edge for
        // legibility against bright video backgrounds and a soft inner
        // chromatic edge from the auroraGlass modifier so the dock
        // doesn't read as a flat pane sitting on top of the scene.
        .auroraGlass(.dock, cornerRadius: 48)
        .background(
            GeometryReader { dockGeometry in
                Color.clear
                    .preference(
                        key: DockFramePreferenceKey.self,
                        value: dockGeometry.frame(in: .global)
                    )
            }
        )
        .onPreferenceChange(DockFramePreferenceKey.self) { frame in
            onDockFrameChange?(frame)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: -6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// Extension to get center point from CGRect
extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

// MARK: - Sound Control Modal (Rebuilt)
struct SoundControlModal: View {
    let track: AudioTrack
    @ObservedObject var audioManager: AudioManager
    let topSafeArea: CGFloat
    let onDismiss: () -> Void

    // CRITICAL: Store track ID at initialization to ensure we always reference the correct track
    private let trackId: UUID

    @State private var currentVolume: Double
    @State private var isDraggingSlider = false
    @EnvironmentObject private var composition: CompositionSession
    
    init(track: AudioTrack, audioManager: AudioManager, topSafeArea: CGFloat, onDismiss: @escaping () -> Void) {
        self.track = track
        self.trackId = track.id // Store ID at init to prevent any reference issues
        self.audioManager = audioManager
        self.topSafeArea = topSafeArea
        self.onDismiss = onDismiss
        self._currentVolume = State(initialValue: track.volume)
    }
    
    // Get current track from audioManager to ensure we have latest data
    // Always use the stored trackId to ensure we get the correct track
    private var currentTrack: AudioTrack? {
        audioManager.tracks.first(where: { $0.id == trackId })
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop - visual only
                Color.black.opacity(0.15)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                
                // Tap-to-dismiss backdrop - modal content will block taps on it
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // If this receives a tap, it's outside the modal (modal blocks taps on it)
                        onDismiss()
                    }
                
                // Modal content - positioned at top, centered
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: topSafeArea)
                    
                    if let track = currentTrack {
                        modalContent(track: track)
                            .background(
                                GeometryReader { modalGeometry in
                                    Color.clear
                                        .preference(
                                            key: ModalFramePreferenceKey.self,
                                            value: modalGeometry.frame(in: .global)
                                        )
                                }
                            )
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            // CRITICAL: Sync volume with actual track state when modal appears
            // This ensures the display is always accurate when opening the modal
            if let currentTrack = currentTrack {
                let actualVolume = currentTrack.volume
                if abs(actualVolume - currentVolume) > 0.001 {
                    currentVolume = actualVolume
                }
            }
        }
        .onChange(of: audioManager.tracks) { oldTracks, newTracks in
            // CRITICAL: Only sync volume for THIS specific track ID
            // Do NOT sync if we're currently dragging the slider
            guard !isDraggingSlider else { return }
            
            // Find the old and new track states for THIS specific track using stored trackId
            guard let oldTrack = oldTracks.first(where: { $0.id == trackId }),
                  let newTrack = newTracks.first(where: { $0.id == trackId }) else {
                return
            }
            
            // Double-check we have the right track
            guard oldTrack.id == trackId && newTrack.id == trackId else {
                print("⚠️ SoundControlModal: Track ID mismatch in onChange!")
                return
            }
            
            // Only sync if the volume actually changed for THIS track
            guard abs(oldTrack.volume - newTrack.volume) > 0.001 else { return }
            
            // Only sync if the new volume is significantly different from our current UI state
            guard abs(newTrack.volume - currentVolume) > 0.01 else { return }
            
            // Update UI to match the new volume
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentVolume = newTrack.volume
            }
        }
    }
    
    @ViewBuilder
    private func modalContent(track: AudioTrack) -> some View {
        let trackColor = SoundColor.colorForTrack(track.name)

        // CRITICAL: Compute display volume once at function level
        // Use actual track volume when not dragging, currentVolume when dragging
        let displayVolume = isDraggingSlider ? currentVolume : (currentTrack?.volume ?? currentVolume)

        return VStack(spacing: AppSpacing.xl) {
            // Aperture (Phase 3.4) — the long-press modal opens like
            // the orb itself dilating. The header is a single round
            // 'aperture' with the track's RecordingPalette burning at
            // the centre; the icon sits inside it like the orb did on
            // the grid. This is the visual continuity cue: 'this sheet
            // *is* that orb you just held'.
            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(RecordingPalette.gradient(for: track))
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    trackColor.opacity(0.55),
                                    trackColor.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )

                    Image(systemName: track.icon)
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                }
                .frame(width: 96, height: 96)
                .shadow(color: trackColor.opacity(0.45), radius: 22, x: 0, y: 8)
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)

                VStack(spacing: 2) {
                    Text(track.name)
                        .font(AuroraTypography.editorial(22, weight: .semibold))
                        .foregroundColor(AuroraColors.TextOnAurora.primary)
                        .lineLimit(1)

                    Text("In the mix")
                        .font(AuroraTypography.editorial(11, weight: .medium))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }
            }

            // Volume row — Aurora typography + chromatic-edge percentage
            // chip. The chip's stroke picks up the live track color so
            // the modal reads as 'tuned to this sound'.
            VStack(spacing: AppSpacing.md) {
                HStack {
                    Text("Volume")
                        .font(AuroraTypography.editorial(13, weight: .semibold))
                        .foregroundColor(AuroraColors.TextOnAurora.secondary)

                    Spacer()

                    Text("\(Int(displayVolume * 100))%")
                        .font(AuroraTypography.mono(15, weight: .semibold))
                        .foregroundColor(AuroraColors.TextOnAurora.primary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(trackColor.opacity(0.45), lineWidth: 1)
                                )
                        )
                }

                volumeSlider(trackColor: trackColor, displayVolume: displayVolume)
            }
            
            // "Use as room background" — only appears when the track carries
            // a video. Tapping toggles the composition's background id; the
            // copy and tint flip when this track is already the room.
            if track.videoUrl != nil {
                let isBackground = composition.backgroundRecordingId == trackId
                Button(action: {
                    InstrumentFeedback.toggle(active: !isBackground)
                    composition.toggle(trackId)
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: isBackground ? "film.fill" : "film")
                            .font(.system(size: 17, weight: .medium))
                        Text(isBackground ? "this scene is the room" : "use as room background")
                            .font(AuroraTypography.editorial(15, weight: .medium))
                    }
                    .foregroundColor(
                        isBackground ? AuroraColors.TextOnAurora.primary : AuroraColors.TextOnAurora.secondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .fill(isBackground ? trackColor.opacity(0.18) : .clear)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isBackground ? trackColor.opacity(0.6) : AuroraColors.Stroke.edge,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(
                    isBackground
                        ? "This scene is currently the room background. Tap to remove."
                        : "Use \(track.name) as the room background"
                )
            }

            // Remove button - standard Button (no gesture conflicts)
            Button(action: {
                InstrumentFeedback.dragEnd()

                print("🗑️ Remove from Mix: \(track.name)")
                
                // CRITICAL: Use stored trackId to ensure we're removing the correct track
                // Toggle track off FIRST (before updating array) - this stops playback
                audioManager.toggleTrack(trackId, isActive: false)
                
                // Then update the array state and volume
                if let index = audioManager.tracks.firstIndex(where: { $0.id == trackId }) {
                    // Double-check we have the right track
                    guard audioManager.tracks[index].id == trackId else {
                        print("⚠️ Remove button: Track ID mismatch!")
                        return
                    }
                    audioManager.tracks[index].isActive = false
                    audioManager.tracks[index].volume = 0.0
                }
                
                // Set volume to 0 - ensures volume is 0
                audioManager.updateTrackVolume(trackId, volume: 0.0)
                
                // Save mix state
                let activeTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
                StatePersistenceService.shared.saveLastActiveMix(activeTracks)
                
                // Close modal after removal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDismiss()
                }
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 17, weight: .medium))
                    Text("Take it out")
                        .font(AuroraTypography.editorial(15, weight: .medium))
                }
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Remove \(track.name) from the mix")
        }
        .padding(.vertical, AppSpacing.xl)
        .padding(.horizontal, AppSpacing.lg)
        .frame(maxWidth: 340)
        .fixedSize(horizontal: false, vertical: true)
        // Aperture chrome (Phase 3.4). Replaces the v1 .liquidGlass card
        // with the Aurora canvas vocabulary + a track-tinted hairline so
        // the sheet reads as part of the same brand surface as the rest
        // of the redesign and clearly carries the active sound's color.
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(trackColor.opacity(0.30), lineWidth: 1)
        }
        .auroraGlass(.canvas, cornerRadius: 28)
        .shadow(color: .black.opacity(0.32), radius: 30, x: 0, y: 14)
    }
    
    @ViewBuilder
    private func volumeSlider(trackColor: Color, displayVolume: Double) -> some View {
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Aurora rail (Phase 3.4). The slider rail picks up the
                // standard Aurora hairline so it reads consistently with
                // the rest of the modal chrome.
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 0.5)
                    )
                    .frame(height: 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingSlider = true
                                let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                                currentVolume = newVolume
                                
                                // CRITICAL: Update volume immediately - ONLY for this specific track ID
                                // Use stored trackId to ensure we're updating the correct track
                                audioManager.updateTrackVolume(trackId, volume: newVolume)
                                
                                // Haptic feedback at milestones
                                let milestone = Int(newVolume * 4)
                                if milestone != Int((value.startLocation.x / geometry.size.width) * 4) {
                                    InstrumentFeedback.threshold(at: (milestone == 0 || milestone == 4) ? .major : .minor)
                                }
                            }
                            .onEnded { value in
                                isDraggingSlider = false
                                let finalVolume = max(0, min(1, value.location.x / geometry.size.width))
                                currentVolume = finalVolume
                                
                                // CRITICAL: Update volume for this specific track only using stored trackId
                                audioManager.updateTrackVolume(trackId, volume: finalVolume)
                                
                                // Save mix state only once at the end of drag (throttled)
                                let activeTracks = audioManager.tracks.filter { $0.isActive && $0.volume > 0 }
                                StatePersistenceService.shared.saveLastActiveMix(activeTracks)
                            }
                    )
                
                // Filled track - visual only
                // CRITICAL: Use displayVolume (actual track volume when not dragging)
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                trackColor,
                                trackColor.opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * displayVolume, height: 6)
                    .shadow(color: trackColor.opacity(0.5), radius: 6)
                    .animation(isDraggingSlider ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: displayVolume)
                    .allowsHitTesting(false)
                
                // Thumb - visual only
                // CRITICAL: Use displayVolume (actual track volume when not dragging)
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: trackColor.opacity(0.7), radius: 6)
                    .overlay(
                        Circle()
                            .stroke(trackColor, lineWidth: 2)
                    )
                    .offset(x: geometry.size.width * displayVolume - 10)
                    .animation(isDraggingSlider ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: currentVolume)
                    .allowsHitTesting(false)
            }
            .frame(height: 20)
        }
        .frame(height: 20)
    }
}

// Preference key for modal frame (if needed for future enhancements)
struct ModalFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Dock Sound Chip
struct DockSoundChip: View {
    let track: AudioTrack
    @ObservedObject var audioManager: AudioManager
    @Binding var soundsInVolumeMode: Set<UUID>
    let availableHeight: CGFloat // Available screen height for movement
    let isOverlay: Bool // Whether rendering in overlay (volume mode) or dock (normal)
    let dockAnchor: CGPoint? // Anchor point in dock (for overlay positioning)
    let onTap: () -> Void // Callback when tapped
    
    // Larger size for dock - more impactful
    private let baseSize: CGFloat = 65
    
    private var trackColor: Color {
        SoundColor.colorForTrack(track.name)
    }
    
    private var isActive: Bool {
        track.isActive
    }
    
    private var volumeMultiplier: Double {
        Double(track.volume)
    }
    
    // Subtle colored glow around icon when active - soft halo effect
    @ViewBuilder
    private var iconGlow: some View {
        if isActive {
            // Soft colored halo around the icon area
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            trackColor.opacity(0.25 * volumeMultiplier),
                            trackColor.opacity(0.1 * volumeMultiplier),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 35
                    )
                )
                .frame(width: baseSize - 10, height: baseSize - 10)
                .blur(radius: 8)
        }
    }
    
    @ViewBuilder
    private var mainGlassCircle: some View {
        ZStack {
            // Base glass layer - clean and neutral
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
            
            // Soft inner highlight for depth
            Circle()
                .fill(innerHighlightGradient)
            
            // Colored border ring when active - subtle accent
            if isActive {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                trackColor.opacity(0.4 * volumeMultiplier),
                                trackColor.opacity(0.25 * volumeMultiplier),
                                trackColor.opacity(0.15 * volumeMultiplier)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            } else {
                // Inactive border — Aurora hairline (Phase 3.2). The
                // v1 used a triple white-opacity gradient; the Aurora
                // token reads cleaner against any scene material.
                Circle()
                    .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1.0)
            }
        }
        .frame(width: baseSize, height: baseSize)
        .clipShape(Circle())
    }
    
    private var innerHighlightGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color.white.opacity(0.25),
                Color.white.opacity(0.1),
                Color.clear
            ],
            center: UnitPoint(x: 0.3, y: 0.3),
            startRadius: 5,
            endRadius: 25
        )
    }
    
    
    // Soft colored shadow when active - subtle depth
    @ViewBuilder
    private var shadowLayer: some View {
        Circle()
            .fill(Color.clear)
            .frame(width: baseSize, height: baseSize)
            .shadow(
                color: isActive ? trackColor.opacity(0.2 * volumeMultiplier) : Color.black.opacity(0.15),
                radius: isActive ? 12 : 8,
                x: 0,
                y: isActive ? 4 : 2
            )
            .shadow(
                color: Color.black.opacity(0.2),
                radius: 6,
                x: 0,
                y: 2
            )
    }
    
    // Neutral icon - always white, never colored
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: track.icon)
            .font(.system(size: 24, weight: .medium, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
    
    var body: some View {
        ZStack {
            // Colored glow halo around icon (when active)
            iconGlow
            
            // Main glass circle with colored border ring
            mainGlassCircle
            
            // Soft shadows for depth
            shadowLayer
            
            // Neutral white icon
            iconView
        }
        .frame(width: baseSize, height: baseSize)
        .contentShape(Rectangle())
        .onTapGesture {
            InstrumentFeedback.tap()
            onTap()
        }
    }
}

// MARK: - Master Volume Slider
struct MasterVolumeSlider: View {
    @ObservedObject var audioManager: AudioManager
    @State private var currentVolume: Double
    @State private var isDraggingSlider = false
    
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        self._currentVolume = State(initialValue: audioManager.masterVolume)
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Minimal speaker icon
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20, height: 20)
            
            // Minimal volume slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background - gesture target (full width and height for easier interaction)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Invisible hit area for easier interaction
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 44) // Standard iOS tap target size
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDraggingSlider {
                                        isDraggingSlider = true
                                    }
                                    let newX = max(0, min(geometry.size.width, value.location.x))
                                    let newVolume = newX / geometry.size.width
                                    
                                    // Clamp volume to valid range
                                    let clampedVolume = min(1.0, max(0.0, newVolume))
                                    
                                    // Update directly without animation during drag for immediate response
                                    currentVolume = clampedVolume
                                    
                                    // Update volume with haptic feedback
                                    audioManager.updateMasterVolume(clampedVolume)
                                    
                                    let oldMilestone = Int((value.startLocation.x / geometry.size.width) * 4)
                                    let newMilestone = Int(clampedVolume * 4)
                                    
                                    if newMilestone != oldMilestone && newMilestone >= 0 && newMilestone <= 4 {
                                        InstrumentFeedback.threshold(at: (newMilestone == 0 || newMilestone == 4) ? .major : .minor)
                                    }
                                }
                                .onEnded { value in
                                    isDraggingSlider = false
                                    // Final volume is already set, just ensure smooth transition
                                    let finalX = max(0, min(geometry.size.width, value.location.x))
                                    let finalVolume = min(1.0, max(0.0, finalX / geometry.size.width))
                                    currentVolume = finalVolume
                                    audioManager.updateMasterVolume(finalVolume)
                                }
                        )
                    
                    // Filled track - visual only
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: geometry.size.width * currentVolume, height: 3)
                        .animation(isDraggingSlider ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: currentVolume)
                        .allowsHitTesting(false)
                    
                    // Custom thumb - visual only
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.white.opacity(0.3), radius: 3)
                        .offset(x: geometry.size.width * currentVolume - 6)
                        .animation(isDraggingSlider ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: currentVolume)
                        .allowsHitTesting(false)
                }
                .frame(height: 44) // Taller frame for easier interaction
            }
            .frame(height: 44) // Taller frame for easier interaction
            
            // Minimal volume percentage
            Text("\(Int(currentVolume * 100))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .onChange(of: audioManager.masterVolume) { _, newValue in
            // Sync with external changes - animate smoothly when not dragging
            if !isDraggingSlider {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentVolume = newValue
                }
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Dock Element Position Preference Key
struct DockElementPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGPoint] = [:]
    static func reduce(value: inout [UUID: CGPoint], nextValue: () -> [UUID: CGPoint]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Dock Frame Preference Key (for drop detection)
struct DockFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Grid Item Position Preference Key (for drag-to-dock)
struct GridItemPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGPoint] = [:]
    static func reduce(value: inout [UUID: CGPoint], nextValue: () -> [UUID: CGPoint]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Helper Functions
private func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
    return Swift.max(min, Swift.min(max, value))
}
