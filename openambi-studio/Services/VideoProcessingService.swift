import Foundation
import AVFoundation

struct VideoAudioExtractionResult {
    let audioURL: URL
    let videoURL: URL
    let duration: TimeInterval
    let fileSize: Int64
}

enum VideoProcessingError: LocalizedError {
    case noAudioTrack
    case exportFailed(String)
    case exportCancelled
    case exportSessionUnavailable

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "The selected video does not contain an audio track."
        case .exportFailed(let message):
            return "Audio extraction failed: \(message)"
        case .exportCancelled:
            return "Audio extraction was cancelled."
        case .exportSessionUnavailable:
            return "Unable to create an export session for this video."
        }
    }
}

class VideoProcessingService {
    static let shared = VideoProcessingService()

    private let fileManager = FileManager.default

    private init() {}

    func extractAudio(from videoURL: URL) async throws -> VideoAudioExtractionResult {
        let asset = AVAsset(url: videoURL)

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw VideoProcessingError.noAudioTrack
        }

        let duration = try await asset.load(.duration)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoProcessingError.exportSessionUnavailable
        }

        let outputURL = temporaryAudioURL()
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: .zero, duration: duration)

        try await exportSession.exportAsync()

        switch exportSession.status {
        case .completed:
            let fileSize = getFileSize(at: outputURL)
            return VideoAudioExtractionResult(
                audioURL: outputURL,
                videoURL: videoURL,
                duration: duration.seconds,
                fileSize: fileSize
            )
        case .failed:
            let message = exportSession.error?.localizedDescription ?? "Unknown export error"
            throw VideoProcessingError.exportFailed(message)
        case .cancelled:
            throw VideoProcessingError.exportCancelled
        default:
            let message = exportSession.error?.localizedDescription ?? "Unexpected export status"
            throw VideoProcessingError.exportFailed(message)
        }
    }

    private func temporaryAudioURL() -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileName = "video_audio_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(fileName)
    }

    private func getFileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
}

private extension AVAssetExportSession {
    func exportAsync() async throws {
        try await withCheckedThrowingContinuation { continuation in
            exportAsynchronously {
                continuation.resume(returning: ())
            }
        }
    }
}
