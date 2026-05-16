import Foundation
import SwiftUI

/// The currently-active "composition" the user is mixing in the Studio.
/// Today this is just the recording whose video should drive the room's
/// immersive background — a single id, persisted to UserDefaults so the
/// same scene is the room across launches.
///
/// Future expansion: arrangement of orbs, saved scene snapshots, etc.
/// Today's surface is intentionally minimal so it can absorb that growth
/// without callers having to change their entry point.
@MainActor
final class CompositionSession: ObservableObject {

    static let shared = CompositionSession()

    @Published private(set) var backgroundRecordingId: UUID?

    private let defaultsKey = "composition.backgroundRecordingId"

    private init() {
        if let s = UserDefaults.standard.string(forKey: defaultsKey),
           let id = UUID(uuidString: s) {
            backgroundRecordingId = id
        }
    }

    /// Set (or clear) the recording id whose video drives the immersive
    /// background. Passing `nil` removes the background and the room
    /// falls back to its purely procedural scene.
    func setBackground(_ id: UUID?) {
        backgroundRecordingId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    /// Toggle helper for long-press modal rows: tapping the same track
    /// twice removes the background, tapping a new one swaps it in.
    func toggle(_ id: UUID) {
        setBackground(backgroundRecordingId == id ? nil : id)
    }

    /// Resolve the active background to a playable URL inside `tracks`.
    /// Returns `nil` if no background is set, the referenced track is
    /// missing from the library, or the track has no `videoUrl`.
    func resolvedVideoURL(in tracks: [AudioTrack]) -> URL? {
        guard let id = backgroundRecordingId,
              let track = tracks.first(where: { $0.id == id }),
              let urlString = track.videoUrl,
              let url = URL(string: urlString) else { return nil }
        return url
    }
}
