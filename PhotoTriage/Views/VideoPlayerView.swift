//
//  VideoPlayerView.swift
//  PhotoTriage
//

import SwiftUI
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let videoAsset: AVAsset  // Changed from AVPlayerItem to AVAsset
    @Binding var isPlaying: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        // Create our own AVPlayerItem from the AVAsset - each view instance gets its own
        let playerItem = AVPlayerItem(asset: videoAsset)
        let player = AVPlayer(playerItem: playerItem)

        player.isMuted = true  // Muted by default
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        playerView.videoGravity = .resizeAspect

        // Store player in coordinator
        context.coordinator.player = player
        context.coordinator.playerItem = playerItem

        // Loop continuously when video ends
        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if isPlaying {
            nsView.player?.play()
        } else {
            nsView.player?.pause()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        nsView.player?.pause()
        nsView.player = nil
        if let observer = coordinator.observer {
            NotificationCenter.default.removeObserver(observer)
            coordinator.observer = nil
        }
    }

    class Coordinator {
        var player: AVPlayer?
        var playerItem: AVPlayerItem?
        var observer: Any?
    }
}
