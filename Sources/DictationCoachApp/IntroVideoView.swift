import AppKit
import AVFoundation
import SwiftUI

struct IntroVideoView: NSViewRepresentable {
    let videoURL: URL
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeNSView(context: Context) -> IntroPlayerNSView {
        let view = IntroPlayerNSView()
        let item = AVPlayerItem(url: videoURL)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        view.player = player
        context.coordinator.observe(item: item)
        player.play()
        return view
    }

    func updateNSView(_ nsView: IntroPlayerNSView, context: Context) {}

    static func dismantleNSView(_ nsView: IntroPlayerNSView, coordinator: Coordinator) {
        nsView.player?.pause()
        nsView.player = nil
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let onFinished: () -> Void
        private var hasFinished = false

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func observe(item: AVPlayerItem) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinish),
                name: .AVPlayerItemFailedToPlayToEndTime,
                object: item
            )
        }

        func stopObserving() {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func playerDidFinish() {
            guard !hasFinished else { return }
            hasFinished = true
            onFinished()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

final class IntroPlayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

struct AppRootView: View {
    @State private var isShowingIntro = true

    private var introURL: URL? {
        Bundle.module.url(forResource: "dictationcoach-intro", withExtension: "mp4")
    }

    var body: some View {
        ZStack {
            ContentView()

            if isShowingIntro, let introURL {
                IntroVideoView(videoURL: introURL) {
                    withAnimation(.easeOut(duration: 0.24)) {
                        isShowingIntro = false
                    }
                }
                .background(Color.black)
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}
