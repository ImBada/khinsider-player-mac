import Foundation

@main
private struct HistoryPlaybackContextBehaviorChecks {
    static func main() throws {
        try checkHistoryPlaybackUsesStoredPlaybackMetadata()
    }

    private static func checkHistoryPlaybackUsesStoredPlaybackMetadata() throws {
        let store = try LibraryStore.inMemory()
        let album = fixtureAlbum()
        let firstTrack = album.tracks[0]
        let secondTrack = album.tracks[1]

        try store.recordPlay(album: album, track: firstTrack)
        try store.recordPlay(album: album, track: secondTrack)

        let history = try store.recentHistory(limit: 2)
        let items = HistoryPlaybackContext.playbackItems(from: history)
        let startingItem = HistoryPlaybackContext.startingItem(
            in: items,
            selectedTrackID: secondTrack.id
        )

        precondition(history.map(\.trackID) == [secondTrack.id, firstTrack.id])
        precondition(history[0].albumTitle == album.title)
        precondition(history[0].albumURL == album.url)
        precondition(history[0].detailURL == secondTrack.detailURL)
        precondition(history[0].duration == secondTrack.duration)
        precondition(items.map(\.track.id) == [secondTrack.id, firstTrack.id])
        precondition(items.map(\.album.title) == [album.title, album.title])
        precondition(startingItem?.track.id == secondTrack.id)
    }

    private static func fixtureAlbum() -> AlbumDetail {
        AlbumDetail(
            id: "history-playback-album",
            title: "History Playback Album",
            url: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/history-playback-album")!,
            alternativeTitles: [],
            platforms: [],
            year: 2026,
            publisher: nil,
            albumType: "Soundtrack",
            fileCount: nil,
            totalDuration: nil,
            totalMP3Size: nil,
            dateAdded: nil,
            artworkURL: URL(string: "https://example.com/history-cover.png"),
            description: nil,
            tracks: [
                Track(
                    id: "history-track-one",
                    albumID: "history-playback-album",
                    discNumber: nil,
                    number: 1,
                    title: "History Track One",
                    detailURL: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/history-playback-album/1")!,
                    duration: 64,
                    mp3Size: nil
                ),
                Track(
                    id: "history-track-two",
                    albumID: "history-playback-album",
                    discNumber: nil,
                    number: 2,
                    title: "History Track Two",
                    detailURL: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/history-playback-album/2")!,
                    duration: 72,
                    mp3Size: nil
                )
            ]
        )
    }
}
