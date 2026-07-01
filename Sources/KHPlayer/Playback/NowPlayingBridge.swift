import MediaPlayer

@MainActor
internal final class NowPlayingBridge {
    internal init() {}

    internal func update(item: PlaybackItem?) {
        guard let item else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.track.title,
            MPMediaItemPropertyAlbumTitle: item.album.title
        ]
    }
}
