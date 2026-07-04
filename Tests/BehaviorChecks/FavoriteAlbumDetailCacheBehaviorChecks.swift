import Foundation
import Combine
import GRDB

@main
private struct FavoriteAlbumDetailCacheBehaviorChecks {
    static func main() throws {
        try checkFavoriteAlbumStoresFullAlbumDetail()
        try checkSingleTrackAlbumDetailDoesNotReplaceFullFavoriteCache()
        try checkFavoriteAlbumEntryCanBeRestoredAfterRemoval()
        try checkFavoriteTrackKeepsAlbumDetailCacheUntilLastReferenceIsRemoved()
        try checkFavoriteTrackEntryCanBeRestoredAfterRemoval()
        try checkFavoriteTrackChangesArePublished()
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

    private static func checkSingleTrackAlbumDetailDoesNotReplaceFullFavoriteCache() throws {
        let store = try LibraryStore.inMemory()
        let firstTrack = album.tracks[0]
        let singleTrackAlbum = album.withTracks([firstTrack])

        try store.setTrackFavorite(album: album, track: firstTrack, isFavorite: true)
        try store.setTrackFavorite(album: singleTrackAlbum, track: firstTrack, isFavorite: true)

        let cachedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(cachedAlbum == album)
    }

    private static func checkFavoriteAlbumEntryCanBeRestoredAfterRemoval() throws {
        let store = try LibraryStore.inMemory()

        try store.setAlbumFavorite(album: album, isFavorite: true)
        let favorite = try store.favoriteAlbums().first
        precondition(favorite?.id == album.id)

        try store.removeFavoriteAlbum(favorite!)

        let removedFavorites = try store.favoriteAlbums()
        precondition(removedFavorites.isEmpty)

        try store.restoreFavoriteAlbum(favorite!, albumDetail: album)

        let restoredFavorites = try store.favoriteAlbums()
        let restoredFavorite = restoredFavorites.first
        let restoredCachedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(restoredFavorites.map(\.id) == [album.id])
        precondition(restoredFavorite?.title == album.title)
        precondition(restoredFavorite?.url == album.url)
        precondition(restoredFavorite?.artworkURL == album.artworkURL)
        precondition(restoredFavorite?.year == album.year)
        precondition(restoredFavorite?.albumType == album.albumType)
        precondition(restoredCachedAlbum == album)
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

    private static func checkFavoriteTrackEntryCanBeRestoredAfterRemoval() throws {
        let store = try LibraryStore.inMemory()
        let track = album.tracks[0]

        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        let favorite = try store.favoriteTracks().first
        precondition(favorite?.id == track.id)

        try store.removeFavoriteTrack(favorite!)

        let removedFavorites = try store.favoriteTracks()
        precondition(removedFavorites.isEmpty)

        try store.restoreFavoriteTrack(favorite!, albumDetail: album)

        let restoredFavorites = try store.favoriteTracks()
        let restoredFavorite = restoredFavorites.first
        let hasRestoredReference = try store.hasFavoriteReference(albumID: album.id)
        let restoredCachedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(restoredFavorites.map(\.id) == [track.id])
        precondition(restoredFavorite?.title == track.title)
        precondition(restoredFavorite?.albumTitle == album.title)
        precondition(restoredFavorite?.artworkURL == album.artworkURL)
        precondition(restoredFavorite?.duration == track.duration)
        precondition(hasRestoredReference)
        precondition(restoredCachedAlbum == album)
    }

    private static func checkFavoriteTrackChangesArePublished() throws {
        let store = try LibraryStore.inMemory()
        let track = album.tracks[0]
        var changes: [FavoriteTrackFavoriteChange] = []
        let cancellable = store.favoriteTrackChanges.sink { change in
            changes.append(change)
        }

        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        let favorite = try store.favoriteTracks().first
        precondition(favorite?.id == track.id)

        try store.removeFavoriteTrack(favorite!)
        try store.restoreFavoriteTrack(favorite!, albumDetail: album)
        cancellable.cancel()

        precondition(changes == [
            FavoriteTrackFavoriteChange(trackID: track.id, albumID: album.id, isFavorite: true, albumDetail: album),
            FavoriteTrackFavoriteChange(trackID: track.id, albumID: album.id, isFavorite: false, albumDetail: album),
            FavoriteTrackFavoriteChange(trackID: track.id, albumID: album.id, isFavorite: true, albumDetail: album)
        ])
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
        fileCount: 2,
        totalDuration: 248,
        totalMP3Size: "6 MB",
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
            ),
            Track(
                id: "persona-vinyl-soundtrack-2022-2",
                albumID: albumSummary.id,
                discNumber: nil,
                number: 2,
                title: "School Days",
                detailURL: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022/2")!,
                duration: 120,
                mp3Size: "3 MB"
            )
        ]
    )
}

private extension AlbumDetail {
    func withTracks(_ tracks: [Track]) -> AlbumDetail {
        AlbumDetail(
            id: id,
            title: title,
            url: url,
            alternativeTitles: alternativeTitles,
            platforms: platforms,
            year: year,
            publisher: publisher,
            albumType: albumType,
            fileCount: fileCount,
            totalDuration: totalDuration,
            totalMP3Size: totalMP3Size,
            dateAdded: dateAdded,
            artworkURL: artworkURL,
            description: description,
            tracks: tracks
        )
    }

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
