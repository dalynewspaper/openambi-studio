import Foundation

class VideoAssetStore {
    static let shared = VideoAssetStore()

    private let fileManager = FileManager.default

    private var videosDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("RecordingVideos", isDirectory: true)
        if !fileManager.fileExists(atPath: videosDir.path) {
            try? fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true)
        }
        return videosDir
    }

    private init() {}

    func saveVideoAsset(sourceURL: URL, id: UUID) throws -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destinationURL = videosDirectory.appendingPathComponent("\(id.uuidString).\(fileExtension)")

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}
