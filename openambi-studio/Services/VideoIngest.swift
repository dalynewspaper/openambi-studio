import Foundation
import AVFoundation
import UIKit
import ImageIO
import CoreLocation

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
    /// Embedded capture instant when the camera wrote the file (best-effort).
    let captureDate: Date?
    /// GPS from container metadata (ISO 6709), if present.
    let gpsCoordinate: CLLocationCoordinate2D?
    /// Reverse-geocoded street-style line for titles / `location_name` (e.g. `Auguststraße 46`).
    let geocodedPlaceTitle: String?
}

/// Prepared import: full copy + metadata, **before** we trim to the user's
/// chosen loop window. Present a timeline UI, then call `finalizeImport`.
struct PendingVideoImport: Identifiable {
    let id: UUID
    let originalSourceURL: URL
    let copiedVideoURL: URL
    let videoExtension: String
    let sourceDuration: TimeInterval
    let videoBytes: Int64
    let captureDate: Date?
    let gpsCoordinate: CLLocationCoordinate2D?
    let geocodedPlaceTitle: String?

    /// Exported loop length (seconds of audio + video we ship).
    static let loopExportSeconds: TimeInterval = 90

    var workDirectory: URL { copiedVideoURL.deletingLastPathComponent() }

    /// Segment length after trimming — full clip when shorter than `loopExportSeconds`.
    var effectiveLoopSeconds: TimeInterval {
        min(Self.loopExportSeconds, sourceDuration)
    }

    /// Maximum loop start (seconds from file start). Zero when the whole clip fits in one loop.
    var maxLoopStart: TimeInterval {
        max(0, sourceDuration - effectiveLoopSeconds)
    }
}

/// Errors that bubble out of `VideoIngest`. `localizedDescription`
/// is written in the openambi voice rather than Apple's defaults so it can
/// be shown directly in the source sheet without rewording at the call site.
enum VideoIngestError: LocalizedError {
    case sourceUnavailable
    case noAudioTrack
    case sourceTooLong(TimeInterval)
    case tooLarge(Int64)
    case extractionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            return "couldn't open this video — try again"
        case .noAudioTrack:
            return "couldn't find any audio in this clip"
        case .sourceTooLong(let seconds):
            let mins = max(1, Int((seconds / 60).rounded(.down)))
            return "this clip is about \(mins) minutes — try a shorter scene (under \(VideoIngest.maxSourceDurationMinutes) minutes)"
        case .tooLarge(let bytes):
            let mb = Int(Double(bytes) / 1_048_576.0)
            return "this clip is \(mb) MB — try a smaller scene (under 200 MB)"
        case .extractionFailed(_):
            return "couldn't lift the audio out of this clip — try another"
        }
    }
}

/// Pulls a video clip into the app's domain: copies the source, lets the user
/// pick which **90 seconds** (or the full clip if shorter) to loop, then
/// extracts trimmed audio + video and a thumbnail.
///
/// Hard cap on **source** length is ~20 minutes; hard cap on bytes is 200 MB.
/// Both throw editorial errors that can be rendered inline in the source sheet.
final class VideoIngest {

    static let shared = VideoIngest()

    /// Length of the ambient loop we export when the source is longer than this.
    static let loopExportSeconds: TimeInterval = PendingVideoImport.loopExportSeconds

    /// Hard cap on **source** duration (minutes). Above this we refuse before segment UI.
    static let maxSourceDurationMinutes: Int = 20

    /// Hard cap on **source** duration (seconds).
    private var maxSourceDurationSeconds: TimeInterval {
        TimeInterval(Self.maxSourceDurationMinutes * 60)
    }

    /// Hard cap on bytes. Above this we refuse before copying so we don't
    /// fill the user's temp space with a clip we can't ship anyway.
    private let maxBytes: Int64 = 200 * 1024 * 1024

    private init() {}

    // MARK: - Public API

    /// Copy + inspect the file and embedded metadata. Does **not** extract audio yet.
    func prepareImport(from sourceURL: URL) async throws -> PendingVideoImport {
        let id = UUID()
        let workDir = try makeWorkDir(for: id)
        let copiedSource = try copySource(from: sourceURL, into: workDir, id: id)

        let videoBytes = (try? fileSize(at: copiedSource)) ?? 0
        if videoBytes > maxBytes {
            cleanupDir(workDir)
            throw VideoIngestError.tooLarge(videoBytes)
        }

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

        if duration > maxSourceDurationSeconds {
            cleanupDir(workDir)
            throw VideoIngestError.sourceTooLong(duration)
        }

        guard hasAudio else {
            cleanupDir(workDir)
            throw VideoIngestError.noAudioTrack
        }

        let (captureDate, gpsCoordinate) = await Self.extractEmbeddedMetadata(from: asset)
        let geocodedPlaceTitle: String?
        if let gpsCoordinate {
            geocodedPlaceTitle = await Self.reverseGeocodePlaceLine(for: gpsCoordinate)
        } else {
            geocodedPlaceTitle = nil
        }

        let ext = copiedSource.pathExtension.lowercased().isEmpty ? "mp4" : copiedSource.pathExtension.lowercased()

        return PendingVideoImport(
            id: id,
            originalSourceURL: sourceURL,
            copiedVideoURL: copiedSource,
            videoExtension: ext,
            sourceDuration: duration,
            videoBytes: videoBytes,
            captureDate: captureDate,
            gpsCoordinate: gpsCoordinate,
            geocodedPlaceTitle: geocodedPlaceTitle
        )
    }

    /// Trim + extract using `loopStart` (seconds from file start). Deletes the full copy.
    func finalizeImport(pending: PendingVideoImport, loopStart rawStart: TimeInterval) async throws -> IngestedVideo {
        let loopStart = min(max(0, rawStart), pending.maxLoopStart)
        let segmentSeconds = pending.effectiveLoopSeconds
        let asset = AVURLAsset(url: pending.copiedVideoURL)

        let startTime = CMTime(seconds: loopStart, preferredTimescale: 600)
        let durationTime = CMTime(seconds: segmentSeconds, preferredTimescale: 600)
        let range = CMTimeRange(start: startTime, duration: durationTime)

        let workDir = pending.workDirectory
        let id = pending.id
        let audioURL = workDir.appendingPathComponent("\(id.uuidString).m4a")
        let trimmedTempURL = workDir.appendingPathComponent("\(id.uuidString)_trim.\(pending.videoExtension)")

        let thumbSeconds = loopStart + segmentSeconds / 2
        let thumbnail = await generateThumbnail(from: asset, atSeconds: thumbSeconds)

        do {
            try await exportAudio(from: asset, to: audioURL, timeRange: range)
        } catch {
            cleanupDir(workDir)
            throw VideoIngestError.extractionFailed(error)
        }

        do {
            try await exportVideoTrim(from: asset, to: trimmedTempURL, timeRange: range, extension: pending.videoExtension)
        } catch {
            try? FileManager.default.removeItem(at: audioURL)
            cleanupDir(workDir)
            throw VideoIngestError.extractionFailed(error)
        }

        try? FileManager.default.removeItem(at: pending.copiedVideoURL)

        let finalVideoURL = workDir.appendingPathComponent("\(id.uuidString).\(pending.videoExtension)")
        if FileManager.default.fileExists(atPath: finalVideoURL.path) {
            try? FileManager.default.removeItem(at: finalVideoURL)
        }
        do {
            try FileManager.default.moveItem(at: trimmedTempURL, to: finalVideoURL)
        } catch {
            try? FileManager.default.removeItem(at: audioURL)
            cleanupDir(workDir)
            throw VideoIngestError.extractionFailed(error)
        }

        let audioBytes = (try? fileSize(at: audioURL)) ?? 0
        let videoBytes = (try? fileSize(at: finalVideoURL)) ?? 0

        return IngestedVideo(
            id: id,
            originalSourceURL: pending.originalSourceURL,
            audioURL: audioURL,
            videoURL: finalVideoURL,
            videoExtension: pending.videoExtension,
            duration: segmentSeconds,
            videoBytes: videoBytes,
            audioBytes: audioBytes,
            thumbnail: thumbnail,
            captureDate: pending.captureDate,
            gpsCoordinate: pending.gpsCoordinate,
            geocodedPlaceTitle: pending.geocodedPlaceTitle
        )
    }

    /// Drop a pending import without finishing (user dismissed segment UI).
    func cleanupPending(_ pending: PendingVideoImport) {
        cleanupDir(pending.workDirectory)
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

    private func exportAudio(from asset: AVAsset, to destination: URL, timeRange: CMTimeRange) async throws {
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
        exporter.timeRange = timeRange

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
                    continuation.resume(throwing: VideoIngestError.extractionFailed(NSError(
                        domain: "VideoIngest",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Audio export ended in unexpected state"]
                    )))
                }
            }
        }
    }

    // MARK: - Video trim

    private func exportVideoTrim(from asset: AVAsset, to destination: URL, timeRange: CMTimeRange, extension ext: String) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoIngestError.extractionFailed(NSError(
                domain: "VideoIngest",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't open video exporter"]
            ))
        }
        exporter.outputURL = destination
        switch ext.lowercased() {
        case "mov": exporter.outputFileType = .mov
        case "m4v": exporter.outputFileType = .m4v
        default: exporter.outputFileType = .mp4
        }
        exporter.timeRange = timeRange

        return try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed, .cancelled:
                    let err = exporter.error ?? NSError(
                        domain: "VideoIngest",
                        code: Int(exporter.status.rawValue),
                        userInfo: [NSLocalizedDescriptionKey: "Video export ended with status \(exporter.status.rawValue)"]
                    )
                    continuation.resume(throwing: VideoIngestError.extractionFailed(err))
                default:
                    continuation.resume(throwing: VideoIngestError.extractionFailed(NSError(
                        domain: "VideoIngest",
                        code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Video export ended in unexpected state"]
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

    // MARK: - Embedded metadata (creation time + GPS)

    /// Reads QuickTime / common tags from the copied file. Export paths from
    /// Photos may omit GPS; we still surface creation date when present.
    private static func extractEmbeddedMetadata(from asset: AVAsset) async -> (Date?, CLLocationCoordinate2D?) {
        let items: [AVMetadataItem]
        do {
            items = try await asset.load(.metadata)
        } catch {
            return (nil, nil)
        }

        var creationDate: Date?
        var coord: CLLocationCoordinate2D?

        for item in items {
            guard let identifier = item.identifier else { continue }

            switch identifier {
            case .commonIdentifierCreationDate, .quickTimeMetadataCreationDate:
                if creationDate == nil {
                    creationDate = resolvedDate(from: item)
                }
            case .quickTimeMetadataLocationISO6709:
                if coord == nil, let s = item.stringValue {
                    coord = parseISO6709(s)
                }
            default:
                let raw = identifier.rawValue.lowercased()
                if coord == nil, raw.contains("iso6709"), let s = item.stringValue {
                    coord = parseISO6709(s)
                }
                if creationDate == nil, raw.contains("creationdate"), raw.contains("quicktime") {
                    creationDate = resolvedDate(from: item)
                }
            }
        }

        return (creationDate, coord)
    }

    private static func resolvedDate(from item: AVMetadataItem) -> Date? {
        if let d = item.dateValue {
            return d as Date
        }
        guard let s = item.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: s) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        // QuickTime sometimes writes `2024-05-16T18:42:05Z`
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return df.date(from: s)
    }

    /// Parses WGS84 geographic point strings (ISO 6709 Annex H compact form),
    /// e.g. `+48.8575+002.3514+035.256/` from iPhone-recorded clips.
    private static func parseISO6709(_ string: String) -> CLLocationCoordinate2D? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"([+-]\d+(?:\.\d+)?)"#, options: []) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let matches = regex.matches(in: trimmed, options: [], range: range)
        guard matches.count >= 2 else { return nil }

        func double(at index: Int) -> Double? {
            guard index < matches.count,
                  let r = Range(matches[index].range, in: trimmed) else { return nil }
            return Double(trimmed[r])
        }

        guard let lat = double(at: 0), let lon = double(at: 1),
              (-90...90).contains(lat), (-180...180).contains(lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func reverseGeocodePlaceLine(for coordinate: CLLocationCoordinate2D) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                guard let pm = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let line = editorialPlaceLine(from: pm).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: line.isEmpty ? nil : line)
            }
        }
    }

    /// A single postcard-style line: street + number, else POI name, else locality.
    private static func editorialPlaceLine(from pm: CLPlacemark) -> String {
        if let thoroughfare = pm.thoroughfare {
            if let num = pm.subThoroughfare {
                return "\(thoroughfare) \(num)"
            }
            return thoroughfare
        }
        if let name = pm.name, name.count > 2 {
            return name
        }
        return pm.locality
            ?? pm.subLocality
            ?? pm.administrativeArea
            ?? ""
    }
}
