import Foundation

@main
private struct FavoritePlaybackContextBehaviorChecks {
    static func main() throws {
        try checkFavoriteSongsPlaybackUsesDisplayedSongsAsQueue()
    }

    private static func checkFavoriteSongsPlaybackUsesDisplayedSongsAsQueue() throws {
        let store = try LibraryStore.inMemory()

        try store.setTrackFavorite(album: firstAlbum, track: firstAlbum.tracks[0], isFavorite: true)
        try store.setTrackFavorite(album: secondAlbum, track: secondAlbum.tracks[0], isFavorite: true)

        let entriesByID = Dictionary(
            uniqueKeysWithValues: try store.favoriteTracks().map { ($0.id, $0) }
        )
        let displayedEntries = [
            entriesByID["favorite-track-one"]!,
            entriesByID["favorite-track-two"]!
        ]

        let items = FavoritePlaybackContext.playbackItems(from: displayedEntries)
        let startingItem = FavoritePlaybackContext.startingItem(
            in: items,
            selectedTrackID: "favorite-track-one"
        )

        precondition(items.map(\.track.id) == ["favorite-track-one", "favorite-track-two"])
        precondition(items.map(\.album.title) == ["First Favorite Album", "Second Favorite Album"])
        precondition(items[0].album.tracks.map(\.id) == ["favorite-track-one"])
        precondition(items[1].album.tracks.map(\.id) == ["favorite-track-two"])
        precondition(startingItem?.track.id == "favorite-track-one")
    }

    private static let firstAlbum = AlbumDetail(
        id: "first-favorite-album",
        title: "First Favorite Album",
        url: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/first-favorite-album")!,
        alternativeTitles: [],
        platforms: [],
        year: nil,
        publisher: nil,
        albumType: nil,
        fileCount: nil,
        totalDuration: nil,
        totalMP3Size: nil,
        dateAdded: nil,
        artworkURL: URL(string: "https://example.com/first.png"),
        description: nil,
        tracks: [
            Track(
                id: "favorite-track-one",
                albumID: "first-favorite-album",
                discNumber: nil,
                number: 1,
                title: "Favorite Track One",
                detailURL: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/first-favorite-album/1")!,
                duration: 60,
                mp3Size: nil
            )
        ]
    )

    private static let secondAlbum = AlbumDetail(
        id: "second-favorite-album",
        title: "Second Favorite Album",
        url: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/second-favorite-album")!,
        alternativeTitles: [],
        platforms: [],
        year: nil,
        publisher: nil,
        albumType: nil,
        fileCount: nil,
        totalDuration: nil,
        totalMP3Size: nil,
        dateAdded: nil,
        artworkURL: URL(string: "https://example.com/second.png"),
        description: nil,
        tracks: [
            Track(
                id: "favorite-track-two",
                albumID: "second-favorite-album",
                discNumber: nil,
                number: 1,
                title: "Favorite Track Two",
                detailURL: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/second-favorite-album/1")!,
                duration: 70,
                mp3Size: nil
            )
        ]
    )
}
