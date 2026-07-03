import Combine
import Foundation

@MainActor
internal final class AlbumDetailViewModel: ObservableObject {
    @Published internal private(set) var album: AlbumDetail?
    @Published internal private(set) var isLoading = false
    @Published internal private(set) var errorMessage: String?
    @Published internal private(set) var isAlbumFavorite = false
    @Published internal private(set) var favoriteTrackIDs = Set<String>()

    internal let summary: AlbumSummary

    private let client: KHClient
    private let libraryStore: LibraryStore
    private let artworkCache: ArtworkCache?
    private var favoriteTrackChangeCancellable: AnyCancellable?

    internal init(
        summary: AlbumSummary,
        client: KHClient,
        libraryStore: LibraryStore,
        artworkCache: ArtworkCache? = nil
    ) {
        self.summary = summary
        self.client = client
        self.libraryStore = libraryStore
        self.artworkCache = artworkCache
        observeFavoriteTrackChanges()
    }

    internal func load() async {
        guard album == nil, !isLoading else {
            return
        }

        if let cachedAlbum = cachedFavoriteAlbumDetail() {
            album = cachedAlbum
            refreshFavoriteState(for: cachedAlbum)
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let html = try await client.html(from: summary.url)
            let loadedAlbum = try AlbumPageParser.parse(html: html, url: summary.url)
            album = loadedAlbum
            refreshFavoriteState(for: loadedAlbum)
            cacheFavoriteAlbumDetailIfReferenced(loadedAlbum)
            errorMessage = nil
        } catch is CancellationError {
            // The view may disappear while the selected album is loading.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    internal func toggleAlbumFavorite() {
        guard let album else {
            return
        }

        do {
            let nextValue = !isAlbumFavorite
            try libraryStore.setAlbumFavorite(
                album: album,
                isFavorite: nextValue
            )
            isAlbumFavorite = nextValue
            if nextValue {
                cacheFavoriteArtwork(for: album)
            } else {
                removeArtworkIfUnreferenced(albumID: album.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    internal func toggleTrackFavorite(_ track: Track) {
        guard let album else {
            return
        }

        do {
            let nextValue = !favoriteTrackIDs.contains(track.id)
            try libraryStore.setTrackFavorite(
                album: album,
                track: track,
                isFavorite: nextValue
            )

            if nextValue {
                favoriteTrackIDs.insert(track.id)
                cacheFavoriteArtwork(for: album)
            } else {
                favoriteTrackIDs.remove(track.id)
                removeArtworkIfUnreferenced(albumID: album.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observeFavoriteTrackChanges() {
        favoriteTrackChangeCancellable = libraryStore.favoriteTrackChanges.sink { [weak self] change in
            Task { @MainActor in
                self?.applyFavoriteTrackChange(change)
            }
        }
    }

    private func applyFavoriteTrackChange(_ change: FavoriteTrackFavoriteChange) {
        guard album?.id == change.albumID else {
            return
        }

        if change.isFavorite {
            favoriteTrackIDs.insert(change.trackID)
        } else {
            favoriteTrackIDs.remove(change.trackID)
        }
    }

    private func cachedFavoriteAlbumDetail() -> AlbumDetail? {
        do {
            return try libraryStore.cachedFavoriteAlbumDetail(albumID: summary.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func refreshFavoriteState(for album: AlbumDetail) {
        do {
            isAlbumFavorite = try libraryStore.isAlbumFavorite(albumID: album.id)
            favoriteTrackIDs = Set(
                try album.tracks
                    .filter { try libraryStore.isTrackFavorite(trackID: $0.id) }
                    .map(\.id)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cacheFavoriteAlbumDetailIfReferenced(_ album: AlbumDetail) {
        do {
            guard try libraryStore.hasFavoriteReference(albumID: album.id) else {
                return
            }

            try libraryStore.storeFavoriteAlbumDetail(album)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cacheFavoriteArtwork(for album: AlbumDetail) {
        guard let artworkCache else {
            return
        }

        let albumID = album.id
        let artworkURL = album.artworkURL ?? summary.artworkURL
        Task { @MainActor in
            do {
                guard let localArtworkURL = try await artworkCache.cacheArtwork(
                    from: artworkURL,
                    albumID: albumID
                ) else {
                    return
                }

                guard try libraryStore.hasFavoriteReference(albumID: albumID) else {
                    try await artworkCache.removeArtwork(albumID: albumID)
                    return
                }

                try libraryStore.updateFavoriteArtwork(
                    albumID: albumID,
                    remoteArtworkURL: artworkURL,
                    localArtworkURL: localArtworkURL
                )
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeArtworkIfUnreferenced(albumID: String) {
        guard let artworkCache else {
            return
        }

        Task { @MainActor in
            do {
                guard !(try libraryStore.hasFavoriteReference(albumID: albumID)) else {
                    return
                }

                try await artworkCache.removeArtwork(albumID: albumID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
