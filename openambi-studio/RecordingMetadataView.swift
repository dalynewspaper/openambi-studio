import SwiftUI
import AVFoundation
import CoreLocation
import UIKit

/// Where the Field Note's underlying media came from. Drives all of the
/// import-vs-record copy and chrome decisions inside `RecordingMetadataView`:
/// the kicker, the orb above the sigil row, the "keep the picture too"
/// toggle, and the save path that talks to Supabase.
enum FieldNoteSource {
    case recorded(RecordingResult)
    case imported(IngestedVideo)

    var duration: TimeInterval {
        switch self {
        case .recorded(let result): return result.duration
        case .imported(let ingest): return ingest.duration
        }
    }

    var fileSize: Int64 {
        switch self {
        case .recorded(let result): return result.fileSize
        case .imported(let ingest): return ingest.audioBytes + ingest.videoBytes
        }
    }

    /// The on-disk URL we ship as the saved track's audio. For imports
    /// this is the audio peeled off the source video.
    var audioFileURL: URL {
        switch self {
        case .recorded(let result): return result.fileURL
        case .imported(let ingest): return ingest.audioURL
        }
    }

    /// Pre-allocated recording id for imports so audio + video file
    /// under the same `{id}.{ext}` in their buckets.
    var preallocatedId: UUID? {
        switch self {
        case .recorded: return nil
        case .imported(let ingest): return ingest.id
        }
    }
}

/// The "Field Note" save flow.
///
/// This is the moment the user is committing a slice of the world to their
/// openambi library. The v1 implementation treated it as a generic settings
/// form (NavigationView, dropdowns, a 21-icon SF symbol picker, a coordinate
/// readout). The redesign treats it as a one-page field note in the same
/// editorial voice as the rest of the IA:
///
///     • FIELD NOTE
///     Just now at Union Square
///     [tape card with duration in editorial mono]
///     [six curated sigils — picking one tints the whole room]
///     [bare title field, hairline rule]
///     [bare description, rotating italic placeholder]
///     [PlaceChip-style strip, lat/lon hides behind a chevron]
///     [Keep this one] — capsule CTA, hairline border picks up sigil color
///
/// The selected sigil maps 1:1 to an existing `SoundColor` preset and is
/// injected as `dominantSoundColor` so AuroraGlass edges, the loader, and
/// the bottom CTA all tint in unison. The upload pipeline, auth gate,
/// location capture, and `AuroraLoader.Modal` overlay are unchanged — this
/// is a surface redesign, not a backend one.
struct RecordingMetadataView: View {
    let source: FieldNoteSource
    let onSave: (AudioTrack) -> Void
    let onCancel: () -> Void

    /// Convenience for legacy callers that still pass a `RecordingResult`
    /// directly. New code should use `init(source:onSave:onCancel:)`.
    init(
        recordingResult: RecordingResult,
        onSave: @escaping (AudioTrack) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.source = .recorded(recordingResult)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    init(
        source: FieldNoteSource,
        onSave: @escaping (AudioTrack) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.source = source
        self.onSave = onSave
        self.onCancel = onCancel
    }

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var supabaseService = SupabaseService()
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedSigil: FieldNoteSigil = .rain
    @State private var revealCoordinates: Bool = false
    @State private var descriptionPlaceholder: String = ""
    @State private var keepVideo: Bool = true

    @State private var showLocationPermissionAlert = false
    @State private var isUploading = false
    @State private var isSavingToLibrary = false
    @State private var saveStatusMessage = "Uploading recording..."
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAuthentication = false

    private var isImported: Bool {
        if case .imported = source { return true }
        return false
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool

    // A small rotating pool. Picking one on appear keeps the placeholder
    // feeling hand-written instead of a template.
    private static let descriptionPlaceholders: [String] = [
        "the cafe was almost empty…",
        "rain on the awning, faint traffic…",
        "wind through the cypress, nothing else…",
        "a kettle, then nothing…",
        "the room before everyone arrived…",
        "the last hour of light…"
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            sceneBackground
            content
            bottomCTA
        }
        .ignoresSafeArea(edges: .bottom)
        .environment(\.dominantSoundColor, selectedSigil.color)
        .animation(Motion.breath, value: selectedSigil)
        .onAppear {
            if case .imported(let ingest) = source {
                title = Self.titleLineForImportedClip(ingest, timeFormatter: shortTimeFormatter)
            } else {
                generateAutoTitle()
            }
            requestLocationIfNeeded()
            descriptionPlaceholder = Self.descriptionPlaceholders.randomElement() ?? ""
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
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showAuthentication) {
            AuthenticationView(authManager: authManager)
                .onDisappear {
                    if authManager.isAuthenticated {
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
                        subtitle: isSavingToLibrary ? "This may take a few seconds…" : nil
                    )
                }
            }
        }
    }

    // MARK: - Scene background

    /// Same vocabulary as Studio/Atelier: AppTheme.background + a sigil-tinted
    /// loading wash. As the user picks a sigil the entire room shifts color.
    private var sceneBackground: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            DynamicLoadingBackground(trackName: selectedSigil.dynamicBackgroundName)
                .opacity(0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(Motion.breath, value: selectedSigil)
        }
    }

    // MARK: - Content stack

    private var content: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer().frame(height: WindowMetrics.topInset + 8)
                    header
                    if isImported {
                        importedSceneOrb
                    }
                    tapeCard
                    sigilRow
                    titleField
                    descriptionField
                    if isImported {
                        keepPictureToggle
                    }
                    placeStrip
                    Spacer().frame(height: 140) // clearance for the bottom CTA
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Editorial header

    /// Parity with `StudioHeader` and `AtelierHeader`: small pip, kerned
    /// uppercase kicker, single mood line. Cancel sits to the left of the
    /// kicker as a ghost capsule rather than a system bar button.
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            cancelButton

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    Circle()
                        .fill(selectedSigil.color)
                        .frame(width: 6, height: 6)
                        .shadow(color: selectedSigil.color.opacity(0.55), radius: 5)
                        .accessibilityHidden(true)

                    Text(kickerText)
                        .font(AuroraTypography.editorial(11, weight: .medium))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }

                Text(sceneMood)
                    .font(AuroraTypography.editorial(15, weight: .semibold))
                    .foregroundColor(AuroraColors.TextOnAurora.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Field note. \(sceneMood). Tap cancel to discard.")
    }

    private var cancelButton: some View {
        Button(action: {
            InstrumentFeedback.tap()
            onCancel()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(.ultraThinMaterial).opacity(0.6)
                )
                .overlay(
                    Circle().strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
                )
        }
        .accessibilityLabel("Discard field note")
    }

    private var kickerText: String {
        isImported ? "A view you brought in" : "Field note"
    }

    /// Scene mood subtitle. For a fresh recording, "Just now" anchors it
    /// in time (or in place when we know one); imports get a single line
    /// that says "this is a scene from somewhere else."
    private var sceneMood: String {
        if isImported {
            return "A scene from somewhere else"
        }
        if let place = locationManager.locationName, !place.isEmpty {
            return "Just now at \(place)"
        }
        return "Just now"
    }

    // MARK: - Imported scene orb

    /// A circular "view you brought in" preview. For imports we lift the
    /// thumbnail to the top of the page so the user feels they're holding
    /// the scene before they commit to it. Honors `accessibilityReduceMotion`:
    /// when reduced, we show the still thumbnail and skip the muted loop.
    @ViewBuilder
    private var importedSceneOrb: some View {
        if case .imported(let ingest) = source {
            HStack {
                Spacer(minLength: 0)
                ZStack {
                    // Sigil-tinted halo so the orb feels part of the
                    // editorial chrome rather than a foreign UIImage.
                    Circle()
                        .fill(selectedSigil.color.opacity(0.18))
                        .frame(width: 156, height: 156)
                        .blur(radius: 18)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [selectedSigil.color.opacity(0.7), selectedSigil.color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: selectedSigil.color.opacity(0.35), radius: 18, x: 0, y: 8)

                    importedSceneOrbInner(ingest: ingest)
                        .frame(width: 138, height: 138)
                        .clipShape(Circle())
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement()
            .accessibilityLabel("Imported scene preview")
        }
    }

    @ViewBuilder
    private func importedSceneOrbInner(ingest: IngestedVideo) -> some View {
        if reduceMotion {
            stillThumbnail(ingest: ingest)
        } else {
            ZStack {
                stillThumbnail(ingest: ingest) // Placeholder while AVPlayer warms up
                RoomBackgroundPlayer(
                    url: ingest.videoURL,
                    blurRadius: 12,
                    dimming: 0.25,
                    isMuted: true
                )
            }
        }
    }

    @ViewBuilder
    private func stillThumbnail(ingest: IngestedVideo) -> some View {
        if let thumb = ingest.thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                selectedSigil.gradient
                Image(systemName: "film.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Keep the picture toggle

    /// "Keep the picture too." Single editorial row controlling whether
    /// the source video is uploaded as the immersive background. Default
    /// on — if the user went to the trouble of bringing a view in, they
    /// probably want the view too.
    private var keepPictureToggle: some View {
        Button(action: {
            withAnimation(Motion.touch) {
                keepVideo.toggle()
                InstrumentFeedback.toggle(active: keepVideo)
            }
        }) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            keepVideo ? selectedSigil.color.opacity(0.7) : AuroraColors.Stroke.edge,
                            lineWidth: 1
                        )
                        .frame(width: 22, height: 22)
                    if keepVideo {
                        Circle()
                            .fill(selectedSigil.color)
                            .frame(width: 12, height: 12)
                            .shadow(color: selectedSigil.color.opacity(0.55), radius: 5)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("keep the picture too")
                        .font(AuroraTypography.editorial(15, weight: .semibold))
                        .foregroundColor(AuroraColors.TextOnAurora.primary)

                    Text("so it can be the room's background")
                        .font(AuroraTypography.editorial(12, weight: .regular))
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
            .auroraGlass(.surface, cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Keep the picture too")
        .accessibilityAddTraits(keepVideo ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Tape card

    /// The "tape" — a circular sigil orb plus duration in editorial mono.
    /// Tap target is intentionally not interactive; this is a status panel,
    /// not a control.
    private var tapeCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(selectedSigil.gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: selectedSigil.color.opacity(0.4), radius: 12, x: 0, y: 6)

                Image(systemName: selectedSigil.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formatDuration(source.duration))
                    .font(AuroraTypography.mono(28, weight: .semibold))
                    .foregroundColor(AuroraColors.TextOnAurora.primary)

                Text(formatFileSize(source.fileSize))
                    .font(AuroraTypography.mono(12, weight: .regular))
                    .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                    .kerning(0.4)
            }

            Spacer()
        }
        .padding(18)
        .auroraGlass(.surface, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formatDuration(source.duration)), \(formatFileSize(source.fileSize))")
    }

    // MARK: - Sigil row

    /// Six curated sigils. Picking one sets the dominant color of the whole
    /// view and decides what the recording is "made of" — both visually
    /// (orb color, glass edge tint, background wash) and in the library
    /// (icon and category fields shipped to the backend).
    private var sigilRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionKicker("What did it sound like?")

            HStack(spacing: 14) {
                ForEach(FieldNoteSigil.allCases) { sigil in
                    sigilOrb(sigil)
                    if sigil != FieldNoteSigil.allCases.last { Spacer(minLength: 0) }
                }
            }
        }
    }

    private func sigilOrb(_ sigil: FieldNoteSigil) -> some View {
        let isSelected = sigil == selectedSigil

        return Button(action: {
            withAnimation(Motion.touch) {
                selectedSigil = sigil
                InstrumentFeedback.tap()
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(sigil.gradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? sigil.color.opacity(0.65) : AuroraColors.Stroke.edge,
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? sigil.color.opacity(0.45) : .clear,
                            radius: isSelected ? 10 : 0,
                            x: 0, y: 4
                        )

                    Image(systemName: sigil.icon)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(isSelected ? .white : AuroraColors.IconOnAurora.inactive)
                }

                Text(sigil.label)
                    .font(AuroraTypography.editorial(10, weight: .medium))
                    .kerning(0.6)
                    .foregroundColor(
                        isSelected
                            ? AuroraColors.TextOnAurora.primary
                            : AuroraColors.TextOnAurora.tertiary
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sigil.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Bare title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionKicker("What will you call it?")

            TextField("", text: $title, prompt: Text(autoTitleSuggestion)
                .font(AuroraTypography.editorial(18, weight: .regular))
                .foregroundColor(AuroraColors.TextOnAurora.quaternary)
            )
            .textFieldStyle(.plain)
            .font(AuroraTypography.editorial(18, weight: .semibold))
            .foregroundColor(AuroraColors.TextOnAurora.primary)
            .submitLabel(.next)
            .focused($titleFocused)
            .onSubmit { descriptionFocused = true }

            Rectangle()
                .fill(titleFocused ? selectedSigil.color.opacity(0.75) : AuroraColors.Stroke.edge)
                .frame(height: 1)
                .animation(Motion.touch, value: titleFocused)
        }
    }

    /// The auto-title we *suggest* if the user doesn't type one — shown
    /// as the placeholder, so the user can either accept it by saving
    /// (we'll substitute it in `handleSave`) or override it.
    private var autoTitleSuggestion: String {
        if case .imported(let ingest) = source {
            return Self.titleLineForImportedClip(ingest, timeFormatter: shortTimeFormatter)
        }
        if let place = locationManager.locationName, !place.isEmpty {
            return "\(place), \(shortTimeFormatter.string(from: Date()))"
        }
        return "Just now, \(shortTimeFormatter.string(from: Date()))"
    }

    /// Postcard-style default name: street from embedded GPS (reverse-geocoded)
    /// plus the clip's capture time — not the device's current place/time.
    private static func titleLineForImportedClip(_ ingest: IngestedVideo, timeFormatter: DateFormatter) -> String {
        let timeSource = ingest.captureDate ?? Date()
        let timeStr = timeFormatter.string(from: timeSource)
        if let line = ingest.geocodedPlaceTitle, !line.isEmpty {
            return "\(line), \(timeStr)"
        }
        if let c = ingest.gpsCoordinate {
            return "\(String(format: "%.4f", c.latitude)), \(String(format: "%.4f", c.longitude)), \(timeStr)"
        }
        if let stem = ingest.sourceDisplayName, !stem.isEmpty {
            return "\(stem) · \(timeStr)"
        }
        return "Imported scene · \(timeStr)"
    }

    // MARK: - Bare description field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionKicker("A few words (optional)")

            TextField(
                "",
                text: $description,
                prompt: Text(descriptionPlaceholder)
                    .font(AuroraTypography.editorial(15, weight: .regular).italic())
                    .foregroundColor(AuroraColors.TextOnAurora.quaternary),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(AuroraTypography.editorial(15, weight: .regular))
            .foregroundColor(AuroraColors.TextOnAurora.primary)
            .lineLimit(2...5)
            .focused($descriptionFocused)

            Rectangle()
                .fill(descriptionFocused ? selectedSigil.color.opacity(0.75) : AuroraColors.Stroke.edge)
                .frame(height: 1)
                .animation(Motion.touch, value: descriptionFocused)
        }
    }

    // MARK: - Place strip

    /// Same vocabulary as `PlaceChip`: a thin glass capsule showing place
    /// and time. Coordinates collapse behind a tap — they have technical
    /// value but no editorial value, so they don't get to sit in the
    /// reading rhythm by default.
    private var placeStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionKicker("Where")

            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    if stripCoordinate != nil {
                        withAnimation(Motion.touch) { revealCoordinates.toggle() }
                        InstrumentFeedback.tap()
                    } else if locationManager.authorizationStatus == .denied {
                        showLocationPermissionAlert = true
                    } else {
                        locationManager.requestLocation()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: hasResolvedStripLocation ? "location.fill" : "location.slash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(
                                hasResolvedStripLocation
                                    ? AuroraColors.IconOnAurora.active
                                    : AuroraColors.IconOnAurora.inactive
                            )

                        Text(placeStripCaption)
                            .font(AuroraTypography.editorial(13, weight: .medium))
                            .foregroundColor(AuroraColors.TextOnAurora.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 6)

                        if stripCoordinate != nil {
                            Image(systemName: revealCoordinates ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AuroraColors.IconOnAurora.inactive)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.65)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if revealCoordinates, let coord = stripCoordinate {
                    Text("\(String(format: "%.4f", coord.latitude)) · \(String(format: "%.4f", coord.longitude))")
                        .font(AuroraTypography.mono(11, weight: .regular))
                        .foregroundColor(AuroraColors.TextOnAurora.quaternary)
                        .padding(.horizontal, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    /// When importing, prefer GPS + capture time from the clip; when recording,
    /// keep the live device snapshot.
    private var stripTimeDate: Date {
        if case .imported(let ingest) = source, let d = ingest.captureDate {
            return d
        }
        return Date()
    }

    private var stripPlaceLabel: String? {
        if case .imported(let ingest) = source {
            if let line = ingest.geocodedPlaceTitle, !line.isEmpty { return line }
            return nil
        }
        return locationManager.locationName
    }

    private var stripCoordinate: CLLocationCoordinate2D? {
        if case .imported(let ingest) = source, let c = ingest.gpsCoordinate {
            return c
        }
        return locationManager.currentLocation?.coordinate
    }

    private var hasResolvedStripLocation: Bool {
        stripCoordinate != nil || !(stripPlaceLabel ?? "").isEmpty
    }

    private var placeStripCaption: String {
        let time = shortTimeFormatter.string(from: stripTimeDate)
        if let place = stripPlaceLabel, !place.isEmpty {
            return "\(place)  ·  \(time)"
        }
        if let coord = stripCoordinate {
            return "\(String(format: "%.4f", coord.latitude)) · \(String(format: "%.4f", coord.longitude))  ·  \(time)"
        }
        if locationManager.authorizationStatus == .denied {
            return "Add location  ·  \(time)"
        }
        return "Just here  ·  \(time)"
    }

    // MARK: - Bottom CTA

    /// "Keep this one" — the editorial verb. Floats over the scene with a
    /// hairline border tinted by the selected sigil, so the button is
    /// visually a member of the room rather than a system-blue intrusion.
    private var bottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.55), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Button(action: handleSave) {
                    HStack(spacing: 10) {
                        Text("Keep this one")
                            .font(AuroraTypography.editorial(16, weight: .semibold))
                            .foregroundColor(canSave ? AuroraColors.TextOnAurora.primary : AuroraColors.TextOnAurora.quaternary)

                        if canSave {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedSigil.color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(canSave ? 0.85 : 0.5)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                canSave ? selectedSigil.color.opacity(0.6) : AuroraColors.Stroke.edge,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: canSave ? selectedSigil.color.opacity(0.25) : .clear, radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.horizontal, 20)
                    .padding(.bottom, WindowMetrics.bottomInset + 14)
            }
            .background(Color.black.opacity(0.85))
        }
    }

    /// We allow saving even with an empty title — we'll substitute the
    /// auto-title suggestion. The only hard gate is that we actually have
    /// the audio bytes on disk.
    private var canSave: Bool {
        FileManager.default.fileExists(atPath: source.audioFileURL.path)
    }

    // MARK: - Section kicker

    private func sectionKicker(_ text: String) -> some View {
        Text(text)
            .font(AuroraTypography.editorial(11, weight: .medium))
            .kerning(1.8)
            .textCase(.uppercase)
            .foregroundColor(AuroraColors.TextOnAurora.tertiary)
    }

    // MARK: - Formatting helpers

    private var shortTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
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

    // MARK: - Auto title

    /// Seed the title field's *prompt* (not its value) with a place + time
    /// suggestion. Leaving `title` empty lets us substitute the suggestion
    /// at save time, so the user doesn't have to type anything to ship.
    private func generateAutoTitle() {
        // We intentionally keep `title` empty — the placeholder shows the
        // suggestion. If the user types nothing, handleSave() picks it up.
    }

    private func requestLocationIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestLocation()
        }
    }

    // MARK: - Save

    private func handleSave() {
        // Substitute the auto-suggested title if the user didn't type one.
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? autoTitleSuggestion
            : title

        // If not signed in, show authentication sheet instead of error
        guard let user = authManager.currentUser else {
            showAuthentication = true
            return
        }

        InstrumentFeedback.tap()
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
                let track = try await uploadForCurrentSource(
                    accessToken: accessToken,
                    user: user,
                    resolvedTitle: resolvedTitle
                )

                await MainActor.run {
                    isUploading = false
                    isSavingToLibrary = true
                    saveStatusMessage = "Saving to your library..."
                }

                await verifyRecordingInDatabase(
                    recordingId: track.id,
                    userId: user.id,
                    accessToken: accessToken,
                    track: track
                )
            } catch let error as SupabaseError {
                switch error {
                case .forbidden, .unauthorized:
                    print("🔄 Token expired, attempting to refresh...")
                    if let refreshedToken = try? await authManager.refreshTokenIfNeeded() {
                        print("✅ Token refreshed, retrying upload...")
                        accessToken = refreshedToken

                        do {
                            let track = try await uploadForCurrentSource(
                                accessToken: accessToken,
                                user: user,
                                resolvedTitle: resolvedTitle
                            )

                            await MainActor.run {
                                isUploading = false
                                isSavingToLibrary = true
                                saveStatusMessage = "Saving to your library..."
                            }

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
                        await MainActor.run {
                            isUploading = false
                            errorMessage = "Authentication expired. Please sign in again."
                            showError = true
                        }
                    }
                default:
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

    /// Branch on the source for the actual upload. Imports pass the
    /// pre-allocated id plus the (optional) video URL; recordings keep
    /// the existing audio-only path verbatim.
    private func uploadForCurrentSource(
        accessToken: String,
        user: User,
        resolvedTitle: String
    ) async throws -> AudioTrack {
        switch source {
        case .recorded(let result):
            return try await supabaseService.uploadRecording(
                fileURL: result.fileURL,
                accessToken: accessToken,
                userId: user.id,
                title: resolvedTitle,
                category: selectedSigil.categoryString,
                description: description.isEmpty ? nil : description,
                icon: selectedSigil.icon,
                duration: result.duration,
                fileSize: result.fileSize,
                locationName: locationManager.locationName,
                latitude: locationManager.currentLocation?.coordinate.latitude,
                longitude: locationManager.currentLocation?.coordinate.longitude,
                videoFileURL: nil,
                videoExtension: nil,
                recordingId: nil
            )

        case .imported(let ingest):
            // Best-effort cleanup of temp files happens on both branches
            // below so we don't leak the ~m4a + video on success or failure.
            let track: AudioTrack
            do {
                track = try await supabaseService.uploadRecording(
                    fileURL: ingest.audioURL,
                    accessToken: accessToken,
                    userId: user.id,
                    title: resolvedTitle,
                    category: selectedSigil.categoryString,
                    description: description.isEmpty ? nil : description,
                    icon: selectedSigil.icon,
                    duration: ingest.duration,
                    fileSize: ingest.audioBytes,
                    locationName: ingest.geocodedPlaceTitle ?? locationManager.locationName,
                    latitude: ingest.gpsCoordinate?.latitude ?? locationManager.currentLocation?.coordinate.latitude,
                    longitude: ingest.gpsCoordinate?.longitude ?? locationManager.currentLocation?.coordinate.longitude,
                    videoFileURL: keepVideo ? ingest.videoURL : nil,
                    videoExtension: keepVideo ? ingest.videoExtension : nil,
                    recordingId: ingest.id
                )
            } catch {
                VideoIngest.shared.cleanup(ingest)
                throw error
            }
            VideoIngest.shared.cleanup(ingest)
            return track
        }
    }

    // MARK: - Verify recording in database

    private func verifyRecordingInDatabase(
        recordingId: UUID,
        userId: UUID,
        accessToken: String,
        track: AudioTrack
    ) async {
        var found = false
        let maxAttempts = 10
        let initialDelay: TimeInterval = 1.0

        try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))

        for attempt in 1...maxAttempts {
            await MainActor.run {
                if attempt == 1 {
                    saveStatusMessage = "Verifying in library..."
                } else {
                    saveStatusMessage = "Verifying in library... (\(attempt)/\(maxAttempts))"
                }
            }

            do {
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

            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(0.8 * 1_000_000_000))
            }
        }

        await MainActor.run {
            saveStatusMessage = "Saved!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSavingToLibrary = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("RecordingSaved"),
                    object: nil,
                    userInfo: ["recordingId": track.id.uuidString]
                )
                print("📢 Posted RecordingSaved notification for: \(track.name) (ID: \(track.id.uuidString)) — verified: \(found)")
                onSave(track)
            }
        }
    }
}

// MARK: - Field note sigil
//
// Six curated presets that map 1:1 to existing `SoundColor` brand colors.
// Picking one decides:
//   • what the orb and edge tints look like
//   • which `DynamicLoadingBackground` washes the room
//   • what icon and category get shipped to the backend
// Keeping the set small is intentional — the v1 had a 21-symbol grid that
// was indistinguishable from any generic SF picker. Six is a curated voice.

private enum FieldNoteSigil: String, CaseIterable, Identifiable {
    case rain, water, wind, fire, voices, quiet

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .rain:   return "cloud.rain.fill"
        case .water:  return "water.waves"
        case .wind:   return "wind"
        case .fire:   return "flame.fill"
        case .voices: return "person.2.wave.2.fill"
        case .quiet:  return "moon.fill"
        }
    }

    var label: String {
        switch self {
        case .rain:   return "Rain"
        case .water:  return "Water"
        case .wind:   return "Wind"
        case .fire:   return "Fire"
        case .voices: return "Voices"
        case .quiet:  return "Quiet"
        }
    }

    /// Light stop. Drives the `dominantSoundColor` environment so AuroraGlass
    /// edges, the CTA hairline, and the loader all tint in unison.
    var color: Color {
        switch self {
        case .rain:   return SoundColor.rain
        case .water:  return SoundColor.ocean
        case .wind:   return SoundColor.wind
        case .fire:   return SoundColor.fireplace
        case .voices: return SoundColor.cafe
        case .quiet:  return SoundColor.meditation
        }
    }

    var darkColor: Color {
        switch self {
        case .rain:   return SoundColor.rainDark
        case .water:  return SoundColor.oceanDark
        case .wind:   return SoundColor.windDark
        case .fire:   return SoundColor.fireplaceDark
        case .voices: return SoundColor.cafeDark
        case .quiet:  return SoundColor.meditationDark
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, darkColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Backend `category` column. Coarser than the sigil set so library
    /// filters keep their current vocabulary.
    var categoryString: String {
        switch self {
        case .rain, .water: return "Water"
        case .wind:         return "Wind"
        case .fire:         return "Fire"
        case .voices:       return "Urban"
        case .quiet:        return "Indoor"
        }
    }

    /// The string `DynamicLoadingBackground` keys off to pick a wash.
    var dynamicBackgroundName: String {
        switch self {
        case .rain:   return "Rain"
        case .water:  return "Ocean"
        case .wind:   return "Wind"
        case .fire:   return "Fireplace"
        case .voices: return "Cafe"
        case .quiet:  return "Meditation"
        }
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

#if DEBUG
#Preview("Field Note – recorded") {
    RecordingMetadataView(
        source: .recorded(RecordingResult(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            duration: 125.5,
            fileSize: 1_200_000,
            averageLevel: 0.5,
            peakLevel: 0.8
        )),
        onSave: { _ in },
        onCancel: {}
    )
    .environmentObject(AuthManager())
}
#endif
