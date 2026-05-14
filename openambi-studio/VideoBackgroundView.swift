import SwiftUI
import AVFoundation

/// Full-screen looping muted video without system `VideoPlayer` chrome.
struct VideoBackgroundView: View {
    let url: URL

    var body: some View {
        LoopingVideoBackgroundRepresentable(url: url)
            .scaledToFill()
            .ignoresSafeArea()
    }
}

private final class PlayerLayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct LoopingVideoBackgroundRepresentable: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerLayerContainerView {
        let v = PlayerLayerContainerView()
        v.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.attach(to: v.playerLayer, url: url)
        return v
    }

    func updateUIView(_ uiView: PlayerLayerContainerView, context: Context) {
        context.coordinator.attach(to: uiView.playerLayer, url: url)
    }

    static func dismantleUIView(_ uiView: PlayerLayerContainerView, coordinator: Coordinator) {
        coordinator.cleanup(layer: uiView.playerLayer)
    }

    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var boundURL: URL?

        func attach(to layer: AVPlayerLayer, url: URL) {
            if boundURL == url, player != nil { return }
            cleanup(layer: layer)
            boundURL = url

            let queuePlayer = AVQueuePlayer()
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            queuePlayer.isMuted = true
            queuePlayer.play()
            layer.player = queuePlayer
            player = queuePlayer
        }

        func cleanup(layer: AVPlayerLayer?) {
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player = nil
            layer?.player = nil
            boundURL = nil
        }
    }
}
