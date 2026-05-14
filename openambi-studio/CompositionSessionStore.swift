import Foundation
import Combine

/// Persists which user recording supplies the immersive mix video background.
final class CompositionSessionStore: ObservableObject {
    private static let defaultsKey = "composition.backgroundRecordingId"

    @Published private(set) var backgroundRecordingId: UUID?

    init() {
        if let str = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let id = UUID(uuidString: str) {
            backgroundRecordingId = id
        }
    }

    func setBackgroundRecording(id: UUID?) {
        backgroundRecordingId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        }
    }

    func clearBackgroundIfRecordingMatches(_ id: UUID) {
        if backgroundRecordingId == id {
            setBackgroundRecording(id: nil)
        }
    }

    /// Clears selection if the recording is gone or no longer has a resolvable video URL.
    func validate(with tracks: [AudioTrack]) {
        guard let id = backgroundRecordingId else { return }
        guard let track = tracks.first(where: { $0.id == id }),
              let v = track.videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty else {
            setBackgroundRecording(id: nil)
            return
        }
        if let url = URL(string: v), url.isFileURL, !FileManager.default.fileExists(atPath: url.path) {
            setBackgroundRecording(id: nil)
        }
    }

    func resolvedVideoURL(tracks: [AudioTrack]) -> URL? {
        validate(with: tracks)
        guard let id = backgroundRecordingId,
              let track = tracks.first(where: { $0.id == id }),
              let s = track.videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        guard let url = URL(string: s) else { return nil }
        if url.isFileURL {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return url
    }
}
