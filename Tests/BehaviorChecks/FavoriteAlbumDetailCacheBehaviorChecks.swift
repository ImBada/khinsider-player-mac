import Foundation
import GRDB

@main
private struct FavoriteAlbumDetailCacheBehaviorChecks {
    static func main() throws {
        try checkFavoriteAlbumStoresFullAlbumDetail()
        try checkFavoriteTrackKeepsAlbumDetailCacheUntilLastReferenceIsRemoved()
    }

    private static func checkFavoriteAlbumStoresFullAlbumDetail() throws {
        let store = try LibraryStore.inMemory()

        try store.setAlbumFavorite(album: album, isFavorite: true)

        let cachedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(cachedAlbum == album)

        try store.setAlbumFavorite(album: album.summary, isFavorite: false)

        let removedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(removedAlbum == nil)
    }

    private static func checkFavoriteTrackKeepsAlbumDetailCacheUntilLastReferenceIsRemoved() throws {
        let store = try LibraryStore.inMemory()
        let track = album.tracks[0]

        try store.setAlbumFavorite(album: album, isFavorite: true)
        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        try store.setAlbumFavorite(album: album.summary, isFavorite: false)

        let cachedWithTrackRemaining = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(cachedWithTrackRemaining == album)

        try store.setTrackFavorite(album: album, track: track, isFavorite: false)

        let removedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(removedAlbum == nil)
    }

    private static let albumSummary = AlbumSummary(
        id: "persona-vinyl-soundtrack-2022",
        title: "Persona Vinyl Soundtrack",
        url: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022")!,
        artworkURL: URL(string: "https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/folder.png"),
        platforms: ["PS1", "Windows"],
        albumType: "Soundtrack",
        year: 2022,
        catalogNumber: nil
    )

    private static let album = AlbumDetail(
        id: albumSummary.id,
        title: albumSummary.title,
        url: albumSummary.url,
        alternativeTitles: ["SMT Persona 1 Vinyl Soundtrack"],
        platforms: albumSummary.platforms,
        year: albumSummary.year,
        publisher: "ATLUS GAME MUSIC",
        albumType: albumSummary.albumType,
        fileCount: 1,
        totalDuration: 128,
        totalMP3Size: "3 MB",
        dateAdded: "2022-01-01",
        artworkURL: albumSummary.artworkURL,
        description: "A test album cached from a favorite action.",
        tracks: [
            Track(
                id: "persona-vinyl-soundtrack-2022-1",
                albumID: albumSummary.id,
                discNumber: nil,
                number: 1,
                title: "Persona",
                detailURL: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022/1")!,
                duration: 128,
                mp3Size: "3 MB"
            )
        ]
    )
}

private extension AlbumDetail {
    var summary: AlbumSummary {
        AlbumSummary(
            id: id,
            title: title,
            url: url,
            artworkURL: artworkURL,
            platforms: platforms,
            albumType: albumType,
            year: year,
            catalogNumber: nil
        )
    }
}
