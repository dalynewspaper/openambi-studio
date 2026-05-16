import SwiftUI
import AVKit
import AVFoundation

/// A muted, looped, blurred video player surface intended to sit *underneath*
/// the Studio constellation. The video is felt, not watched — orbs and chrome
/// remain readable through the soft blur + dim layered on top.
///
/// Two layers, bottom to top:
/// 1. `AVPlayerLayer` (resizeAspectFill) — drives playback at native quality.
/// 2. `UIVisualEffectView(systemUltraThinMaterialDark)` + a black dim overlay
///    — kill perceived detail so the room reads as *the place* of a sound,
///    not a movie.
///
/// Audio is always muted (lock-screen + Studio audio takes priority). The
/// looper is seamless via `AVQueuePlayer` + `AVPlayerLooper`. Replacing the
/// URL replaces only `currentItem`; we don't recreate the whole AVPlayer.
struct RoomBackgroundPlayer: UIViewRepresentable {
    let url: URL
    var blurRadius: CGFloat = 18
    var dimming: Double = 0.45
    var isMuted: Bool = true

    func makeUIView(context: Context) -> RoomBackgroundView {
        let view = RoomBackgroundView()
        view.configure(url: url, blurRadius: blurRadius, dimming: dimming, isMuted: isMuted)
        return view
    }

    func updateUIView(_ uiView: RoomBackgroundView, context: Context) {
        uiView.configure(url: url, blurRadius: blurRadius, dimming: dimming, isMuted: isMuted)
    }

    static func dismantleUIView(_ uiView: RoomBackgroundView, coordinator: ()) {
        uiView.teardown()
    }
}

/// UIView host so we can set `layerClass = AVPlayerLayer` and lay out the
/// player, blur, and dim overlay in one place.
final class RoomBackgroundView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let dimView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill

        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.isUserInteractionEnabled = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    func configure(url: URL, blurRadius: CGFloat, dimming: Double, isMuted: Bool) {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(dimming))

        // Only rebuild the player when the URL actually changed; otherwise
        // we'd snap playback every time the parent re-rendered (volume tick,
        // dominant color change, etc.).
        if currentURL != url {
            currentURL = url
            rebuildPlayer(for: url, isMuted: isMuted)
        } else {
            queuePlayer?.isMuted = isMuted
        }
    }

    private func rebuildPlayer(for url: URL, isMuted: Bool) {
        teardown()

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = isMuted
        // Allow continued playback even when the silent switch is on or
        // another audio session has priority — without affecting it.
        player.actionAtItemEnd = .advance
        player.automaticallyWaitsToMinimizeStalling = true

        let looper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player

        self.queuePlayer = player
        self.looper = looper

        player.play()
    }

    func teardown() {
        queuePlayer?.pause()
        playerLayer.player = nil
        looper = nil
        queuePlayer = nil
    }

    deinit {
        teardown()
    }
}
