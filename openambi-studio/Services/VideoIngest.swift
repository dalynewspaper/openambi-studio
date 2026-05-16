import Foundation
import AVFoundation
import UIKit
import ImageIO

/// A clip the user brought into the Field — the audio peeled off into our
/// own `.m4a`, the source video copied into our own temp dir (so the
/// PHPicker / file provider URL can be released immediately), and a
/// representative thumbnail rendered for the save view.
///
/// `id` is pre-allocated so the audio and video upload to the same
/// `{id}.{ext}` filename in their respective buckets. Callers MUST invoke
/// `VideoIngest.shared.cleanup(...)` once the upload chain has succeeded
/// or failed; the temp dir is otherwise long-lived for the app session.
struct IngestedVideo: Identifiable {
    let id: UUID
    let originalSourceURL: URL
    let audioURL: URL
    let videoURL: URL
    let videoExtension: String
    let duration: TimeInterval
    let videoBytes: Int64
    let audioBytes: Int64
    let thumbnail: UIImage?
}

/// Errors that bubble out of `VideoIngest.ingest(from:)`. `localizedDescription`
/// is written in the openambi voice rather than Apple's defaults so it can
/// be shown directly in the source sheet without rewording at the call site.
enum VideoIngestError: LocalizedError {
    case sourceUnavailable
    case noAudioTrack
    case tooLong(TimeInterval)
    case tooLarge(Int64)
    case extractionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            return "couldn't open this video — try again"
        case .noAudioTrack:
            return "couldn't find any audio in this clip"
        case .tooLong(let seconds):
            let secs = Int(seconds.rounded())
            return "this clip is \(secs) seconds — try a shorter scene (under 90s)"
        case .tooLarge(let bytes):
            let mb = Int(Double(bytes) / 1_048_576.0)
            return "this clip is \(mb) MB — try a smaller scene (under 200 MB)"
        case .extractionFailed:
            return "couldn't lift the audio out of this clip — try another"
        }
    }
}

/// Pulls a video clip into the app's domain: copies the source, extracts
/// audio, generates a thumbnail. All heavy work hops off the main actor;
/// the public API is `async throws` so callers can `await` on the main
/// actor without blocking it.
///
/// Soft cap (length) is 90s; hard cap (bytes) is 200 MB. Both throw
/// editorial errors that can be rendered inline in the source sheet.
final class VideoIngest {

    static let shared = VideoIngest()

    /// Soft cap on clip length. Longer scenes are rejected — the room
    /// is meant to feel like a "view", not a movie.
    private let maxDurationSeconds: TimeInterval = 90

    /// Hard cap on bytes. Above this we refuse before copying so we don't
    /// fill the user's temp space with a clip we can't ship anyway.
    private let maxBytes: Int64 = 200 * 1024 * 1024

    private init() {}

    // MARK: - Public API

    /// Ingest a video at `sourceURL`. The URL may be:
    /// - a Photos picker file URL (Transferable FileRepresentation)
    /// - a security-scoped UIDocumentPicker URL
    /// - a plain file URL inside our own sandbox
    ///
    /// In all three cases we end up with a copy under our temp dir, so
    /// the caller can release whatever URL they handed us.
    func ingest(from sourceURL: URL) async throws -> IngestedVideo {
        // Pre-allocate id so audio + video upload to the same {id}.{ext}.
        let id = UUID()
        let workDir = try makeWorkDir(for: id)

        // 1. Resolve the security-scoped URL into a local copy we control.
        let copiedSource = try copySource(from: sourceURL, into: workDir, id: id)

        // 2. Cheap byte cap before we do anything expensive.
        let videoBytes = (try? fileSize(at: copiedSource)) ?? 0
        if videoBytes > maxBytes {
            cleanupDir(workDir)
            throw VideoIngestError.tooLarge(videoBytes)
        }

        // 3. Inspect duration + audio track presence.
        let asset = AVURLAsset(url: copiedSource)
        let duration: TimeInterval
        let hasAudio: Bool
        do {
            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            hasAudio = !audioTracks.isEmpty
        } catch {
            cleanupDir(workDir)
            throw VideoIngestError.extractionFailed(error)
        }

        guard duration.isFinite, duration > 0 else {
            cleanupDir(workDir)
            throw VideoIngestError.sourceUnavailable
        }

        if duration > maxDurationSeconds {
            cleanupDir(workDir)
            throw VideoIngestError.tooLong(duration)
        }

        guard hasAudio else {
            cleanupDir(workDir)
            throw VideoIngestError.noAudioTrack
        }

        // 4. Extract audio to .m4a using AppleM4A preset.
        let audioURL = workDir.appendingPathComponent("\(id.uuidString).m4a")
        do {
            try await exportAudio(from: asset, to: audioURL)
        } catch {
            cleanupDir(workDir)
            throw VideoIngestError.extractionFailed(error)
        }
        let audioBytes = (try? fileSize(at: audioURL)) ?? 0

        // 5. Generate a representative middle-frame thumbnail.
        let thumbnail = await generateThumbnail(from: asset, atSeconds: duration / 2)

        return IngestedVideo(
            id: id,
            originalSourceURL: sourceURL,
            audioURL: audioURL,
            videoURL: copiedSource,
            videoExtension: copiedSource.pathExtension.lowercased().isEmpty ? "mp4" : copiedSource.pathExtension.lowercased(),
            duration: duration,
            videoBytes: videoBytes,
            audioBytes: audioBytes,
            thumbnail: thumbnail
        )
    }

    /// Delete the temp dir associated with an ingest. Safe to call more
    /// than once; failures are swallowed (these are best-effort cleanups).
    func cleanup(_ ingest: IngestedVideo) {
        let dir = ingest.audioURL.deletingLastPathComponent()
        cleanupDir(dir)
    }

    // MARK: - Internals

    private func ingestRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("openambi-ingest", isDirectory: true)
    }

    private func makeWorkDir(for id: UUID) throws -> URL {
        let root = ingestRoot()
        let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copy bytes from `sourceURL` into `workDir/<id>.<ext>`. Handles
    /// security-scoped resources (UIDocumentPicker) by starting/stopping
    /// access around the copy. For PHPicker-derived URLs the scope call
    /// is a no-op, which is fine.
    private func copySource(from sourceURL: URL, into workDir: URL, id: UUID) throws -> URL {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scoped { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let rawExt = sourceURL.pathExtension.lowercased()
        let ext: String
        switch rawExt {
        case "mp4", "mov", "m4v": ext = rawExt
        default: ext = "mp4"
        }
        let dest = workDir.appendingPathComponent("\(id.uuidString).\(ext)")

        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
        } catch {
            // Fall back to a raw Data round-trip if the copy fails — some
            // file providers don't allow plain copyItem and want a read.
            if let data = try? Data(contentsOf: sourceURL, options: .mappedIfSafe) {
                try data.write(to: dest, options: .atomic)
            } else {
                throw VideoIngestError.sourceUnavailable
            }
        }
        return dest
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func cleanupDir(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Audio extraction

    private func exportAudio(from asset: AVAsset, to destination: URL) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoIngestError.extractionFailed(NSError(
                domain: "VideoIngest",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't open exporter"]
            ))
        }
        exporter.outputURL = destination
        exporter.outputFileType = .m4a

        return try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed, .cancelled:
                    let err = exporter.error ?? NSError(
                        domain: "VideoIngest",
                        code: Int(exporter.status.rawValue),
                        userInfo: [NSLocalizedDescriptionKey: "Audio export ended with status \(exporter.status.rawValue)"]
                    )
                    continuation.resume(throwing: VideoIngestError.extractionFailed(err))
                default:
                    // .waiting / .exporting / .unknown — should not be terminal.
                    continuation.resume(throwing: VideoIngestError.extractionFailed(NSError(
                        domain: "VideoIngest",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Audio export ended in unexpected state"]
                    )))
                }
            }
        }
    }

    // MARK: - Thumbnail

    private func generateThumbnail(from asset: AVAsset, atSeconds seconds: TimeInterval) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1200, height: 1200) // ~600pt @2x

        let primary = CMTime(seconds: max(0.0, seconds), preferredTimescale: 600)
        if let image = await singleFrame(generator: generator, at: primary) {
            return image
        }

        // Fall back to first frame if the middle-frame request failed.
        let fallback = CMTime(seconds: 0, preferredTimescale: 600)
        return await singleFrame(generator: generator, at: fallback)
    }

    private func singleFrame(generator: AVAssetImageGenerator, at time: CMTime) async -> UIImage? {
        await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
