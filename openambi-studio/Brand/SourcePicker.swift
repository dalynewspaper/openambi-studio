import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreTransferable

/// Editorial sheet that lets the user "bring something in" — a video from
/// their Photos library or a file from Files. Picking emits a single
/// on-disk URL via `onPicked`; the caller is responsible for running the
/// ingest and dismissing.
///
/// Voice notes:
/// - kicker is `BRING IT IN`
/// - rows read as quiet verbs: "from your photos", "from files"
/// - inline errors are editorial, not system alerts
struct SourcePicker: View {
    let onPicked: (URL) -> Void
    let onCancel: () -> Void
    /// Editorial error message surfaced by the parent (e.g. the ingest
    /// pipeline). Binding so the parent can clear it on retry.
    @Binding var externalError: String?

    @State private var photoSelection: PhotosPickerItem?
    @State private var showDocumentPicker = false
    @State private var internalError: String?
    @State private var loadingFromPhotos = false

    init(
        onPicked: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void,
        externalError: Binding<String?> = .constant(nil)
    ) {
        self.onPicked = onPicked
        self.onCancel = onCancel
        self._externalError = externalError
    }

    private var visibleError: String? {
        externalError ?? internalError
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                Spacer().frame(height: WindowMetrics.topInset + 4)
                header
                rows
                if let visibleError {
                    inlineErrorView(visibleError)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, WindowMetrics.bottomInset + 24)
        }
        .photosPicker(
            isPresented: photosPickerBinding,
            selection: $photoSelection,
            matching: .videos,
            photoLibrary: .shared()
        )
        .onChange(of: photoSelection) { _, newItem in
            guard let newItem else { return }
            internalError = nil
            externalError = nil
            loadingFromPhotos = true
            Task {
                do {
                    let url = try await loadPhotosVideo(item: newItem)
                    await MainActor.run {
                        loadingFromPhotos = false
                        photoSelection = nil
                        InstrumentFeedback.tap()
                        onPicked(url)
                    }
                } catch {
                    await MainActor.run {
                        loadingFromPhotos = false
                        photoSelection = nil
                        internalError = "couldn't read this clip from photos — try another"
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentVideoPickerRepresentable { url in
                showDocumentPicker = false
                internalError = nil
                externalError = nil
                InstrumentFeedback.tap()
                onPicked(url)
            } onCancel: {
                showDocumentPicker = false
            }
            .ignoresSafeArea()
        }
    }

    // The PhotosPicker presentation flag has to be a Bool binding; this
    // proxies our internal "is the picker showing" state without giving
    // PhotosPicker a chance to fight with our @State.
    @State private var showPhotosPicker = false
    private var photosPickerBinding: Binding<Bool> {
        Binding(
            get: { showPhotosPicker },
            set: { showPhotosPicker = $0 }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 6, height: 6)
                    .shadow(color: .white.opacity(0.4), radius: 4)
                    .accessibilityHidden(true)

                Text("Bring it in")
                    .font(AuroraTypography.editorial(11, weight: .medium))
                    .kerning(2.4)
                    .textCase(.uppercase)
                    .foregroundColor(AuroraColors.TextOnAurora.tertiary)
            }

            Text("a scene from somewhere else")
                .font(AuroraTypography.editorial(18, weight: .semibold))
                .foregroundColor(AuroraColors.TextOnAurora.primary)
        }
    }

    // MARK: - Rows

    private var rows: some View {
        VStack(spacing: 14) {
            sourceRow(
                glyph: "photo.on.rectangle.angled",
                title: "from your photos",
                hint: loadingFromPhotos ? "listening to your scene…" : nil,
                disabled: loadingFromPhotos
            ) {
                internalError = nil
                externalError = nil
                showPhotosPicker = true
            }

            sourceRow(
                glyph: "folder",
                title: "from files",
                hint: nil,
                disabled: loadingFromPhotos
            ) {
                internalError = nil
                externalError = nil
                showDocumentPicker = true
            }

            cancelRow
        }
    }

    private func sourceRow(
        glyph: String,
        title: String,
        hint: String?,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
                        )
                    Image(systemName: glyph)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AuroraColors.IconOnAurora.active)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AuroraTypography.editorial(16, weight: .semibold))
                        .foregroundColor(AuroraColors.TextOnAurora.primary)

                    if let hint {
                        Text(hint)
                            .font(AuroraTypography.editorial(12, weight: .regular).italic())
                            .foregroundColor(AuroraColors.TextOnAurora.tertiary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AuroraColors.IconOnAurora.inactive)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .auroraGlass(.surface, cornerRadius: 20)
        .opacity(disabled ? 0.55 : 1.0)
        .disabled(disabled)
        .accessibilityLabel(title)
    }

    private var cancelRow: some View {
        Button {
            InstrumentFeedback.tap()
            onCancel()
        } label: {
            Text("cancel")
                .font(AuroraTypography.editorial(15, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityLabel("Cancel")
    }

    private func inlineErrorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 2)

            Text(message)
                .font(AuroraTypography.editorial(13, weight: .regular))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auroraGlass(.canvas, cornerRadius: 16)
    }

    // MARK: - Photos transferable

    /// Read the picked photo as our `VideoTransferable`, which writes
    /// the underlying file into our temp dir so the URL is stable for
    /// the rest of the ingest pipeline.
    private func loadPhotosVideo(item: PhotosPickerItem) async throws -> URL {
        guard let transferable = try await item.loadTransferable(type: VideoTransferable.self) else {
            throw VideoIngestError.sourceUnavailable
        }
        return transferable.url
    }
}

/// On-disk vehicle for Photos picker videos. The receiving block runs in
/// PhotosUI's own scratch directory; we copy the file out into our own
/// temp dir immediately so we don't depend on the system cleaning ours up.
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { transferable in
            SentTransferredFile(transferable.url)
        } importing: { received in
            let id = UUID().uuidString
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("openambi-source-\(id).\(ext)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

// MARK: - Document picker representable

/// Files-based video picker. Forces copy mode (not in-place) so the URL
/// we get back is stable for the rest of the ingest pipeline.
struct DocumentVideoPickerRepresentable: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        controller.allowsMultipleSelection = false
        controller.shouldShowFileExtensions = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        let onCancel: () -> Void

        init(onPicked: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPicked(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
