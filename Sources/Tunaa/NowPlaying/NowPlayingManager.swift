import AppKit
import MediaPlayer

@MainActor
final class NowPlayingManager {
    private let player: YouTubePlayerController
    private var artworkCache: [String: NSImage] = [:]

    init(player: YouTubePlayerController) {
        self.player = player
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak player] _ in player?.play(); return .success }
        center.pauseCommand.addTarget { [weak player] _ in player?.pause(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak player] _ in player?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak player] _ in player?.playNext(); return .success }
        center.previousTrackCommand.addTarget { [weak player] _ in player?.playPrevious(); return .success }
    }

    func update() {
        guard let current = player.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.channel,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0,
        ]
        if let image = artworkCache[current.id] {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        } else {
            loadArtwork(for: current)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = player.isPlaying ? .playing : .paused
    }

    private func loadArtwork(for ref: VideoRef) {
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: ref.thumbnailURL),
                  let image = NSImage(data: data) else { return }
            artworkCache[ref.id] = image
        }
    }
}
