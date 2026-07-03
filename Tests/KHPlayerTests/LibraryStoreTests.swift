import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. These helpers document the
// intended LibraryStore checks without importing a test framework.
internal struct LibraryStoreTests {
    internal func favoriteAlbumRoundTripsTrueThenFalse() throws {
        let store = try LibraryStore.inMemory()
        let album = Self.albumSummary

        try store.setAlbumFavorite(album: album, isFavorite: true)
        let isFavorite = try store.isAlbumFavorite(albumID: album.id)
        precondition(isFavorite)

        let favorites = try store.favoriteAlbums()
        precondition(favorites.map(\.id) == [album.id])
        precondition(favorites.first?.title == album.title)
        precondition(favorites.first?.url == album.url)
        precondition(favorites.first?.localArtworkURL == nil)

        try store.setAlbumFavorite(album: album, isFavorite: false)
        let isFavoriteAfterRemoval = try store.isAlbumFavorite(albumID: album.id)
        precondition(!isFavoriteAfterRemoval)
    }

    internal func favoriteAlbumEntryCanBeRestoredAfterRemoval() throws {
        let store = try LibraryStore.inMemory()
        let album = Self.albumDetail

        try store.setAlbumFavorite(album: album, isFavorite: true)
        let favorite = try store.favoriteAlbums().first
        precondition(favorite?.id == album.id)

        try store.removeFavoriteAlbum(favorite!)
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

    internal func favoriteTrackRoundTripsTrueThenFalse() throws {
        let store = try LibraryStore.inMemory()
        let album = Self.albumDetail
        let track = album.tracks[0]

        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        let isFavorite = try store.isTrackFavorite(trackID: track.id)
        precondition(isFavorite)

        let favorites = try store.favoriteTracks()
        precondition(favorites.map(\.id) == [track.id])
        precondition(favorites.first?.title == track.title)
        precondition(favorites.first?.albumTitle == album.title)
        precondition(favorites.first?.artworkURL == album.artworkURL)
        precondition(favorites.first?.localArtworkURL == nil)
        precondition(favorites.first?.duration == track.duration)

        try store.setTrackFavorite(album: album, track: track, isFavorite: false)
        let isFavoriteAfterRemoval = try store.isTrackFavorite(trackID: track.id)
        precondition(!isFavoriteAfterRemoval)
    }

    internal func favoriteTrackEntryCanBeRemovedWithoutAlbumDetail() throws {
        let store = try LibraryStore.inMemory()
        let album = Self.albumDetail
        let track = album.tracks[0]

        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        let favorite = try store.favoriteTracks().first
        precondition(favorite?.id == track.id)

        try store.removeFavoriteTrack(favorite!)

        let remainingFavorites = try store.favoriteTracks()
        let hasReference = try store.hasFavoriteReference(albumID: album.id)
        precondition(remainingFavorites.isEmpty)
        precondition(!hasReference)
    }

    internal func favoriteTrackEntryCanBeRestoredAfterRemoval() throws {
        let store = try LibraryStore.inMemory()
        let album = Self.albumDetail
        let track = album.tracks[0]

        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        let favorite = try store.favoriteTracks().first
        precondition(favorite?.id == track.id)

        try store.removeFavoriteTrack(favorite!)
        try store.restoreFavoriteTrack(favorite!, albumDetail: album)

        let restoredFavorites = try store.favoriteTracks()
        let restoredFavorite = restoredFavorites.first
        let hasReference = try store.hasFavoriteReference(albumID: album.id)
        let restoredCachedAlbum = try store.cachedFavoriteAlbumDetail(albumID: album.id)
        precondition(restoredFavorites.map(\.id) == [track.id])
        precondition(restoredFavorite?.title == track.title)
        precondition(restoredFavorite?.albumTitle == album.title)
        precondition(restoredFavorite?.artworkURL == album.artworkURL)
        precondition(restoredFavorite?.duration == track.duration)
        precondition(hasReference)
        precondition(restoredCachedAlbum == album)
    }

    internal func favoriteArtworkCacheMetadataUpdatesAllReferences() throws {
        let store = try LibraryStore.inMemory()
        let album = Self.albumDetail
        let track = album.tracks[0]
        let localArtworkURL = URL(fileURLWithPath: "/tmp/persona-vinyl-artwork.png")

        try store.setAlbumFavorite(album: Self.albumSummary, isFavorite: true)
        try store.setTrackFavorite(album: album, track: track, isFavorite: true)
        try store.updateFavoriteArtwork(
            albumID: album.id,
            remoteArtworkURL: album.artworkURL,
            localArtworkURL: localArtworkURL
        )

        let hasReferenceBeforeRemoval = try store.hasFavoriteReference(albumID: album.id)
        let favoriteAlbum = try store.favoriteAlbums().first
        let favoriteTrack = try store.favoriteTracks().first
        precondition(hasReferenceBeforeRemoval)
        precondition(favoriteAlbum?.localArtworkURL == localArtworkURL)
        precondition(favoriteTrack?.localArtworkURL == localArtworkURL)

        try store.setAlbumFavorite(album: Self.albumSummary, isFavorite: false)
        let hasReferenceWithTrackRemaining = try store.hasFavoriteReference(albumID: album.id)
        precondition(hasReferenceWithTrackRemaining)

        try store.setTrackFavorite(album: album, track: track, isFavorite: false)
        let hasReferenceAfterRemoval = try store.hasFavoriteReference(albumID: album.id)
        precondition(!hasReferenceAfterRemoval)
    }

    internal func recentHistoryReturnsLatestPlayFirst() throws {
        let store = try LibraryStore.inMemory()

        try store.recordPlay(
            trackID: "persona-vinyl-soundtrack-2022-1",
            albumID: "persona-vinyl-soundtrack-2022",
            title: "Persona"
        )
        try store.recordPlay(
            trackID: "persona-vinyl-soundtrack-2022-2",
            albumID: "persona-vinyl-soundtrack-2022",
            title: "Dream of Butterfly"
        )

        let history = try store.recentHistory(limit: 2)
        precondition(history.map(\.trackID) == [
            "persona-vinyl-soundtrack-2022-2",
            "persona-vinyl-soundtrack-2022-1"
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

    private static let albumDetail = AlbumDetail(
        id: albumSummary.id,
        title: albumSummary.title,
        url: albumSummary.url,
        alternativeTitles: [],
        platforms: albumSummary.platforms,
        year: albumSummary.year,
        publisher: "ATLUS GAME MUSIC",
        albumType: albumSummary.albumType,
        fileCount: 1,
        totalDuration: 128,
        totalMP3Size: "3 MB",
        dateAdded: nil,
        artworkURL: albumSummary.artworkURL,
        description: nil,
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
