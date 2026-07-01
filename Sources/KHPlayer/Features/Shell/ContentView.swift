import SwiftUI

struct ContentView: View {
    @Environment(\.appState) private var optionalAppState

    // Keeps shell selection in SwiftUI State while avoiding the local
    // CommandLineTools SDK's missing @State macro plugin.
    private var _selectedDestination = State<SidebarDestination?>(initialValue: .search)
    private var _selectedAlbum = State<AlbumSummary?>(initialValue: nil)
    private var _sidebarVisibility = State<NavigationSplitViewVisibility>(initialValue: .all)
    private var _playbackErrorMessage = State<String?>(initialValue: nil)

    private var selectedDestination: SidebarDestination? {
        get {
            _selectedDestination.wrappedValue
        }
        nonmutating set {
            _selectedDestination.wrappedValue = newValue
        }
    }

    private var selectedAlbum: AlbumSummary? {
        get {
            _selectedAlbum.wrappedValue
        }
        nonmutating set {
            _selectedAlbum.wrappedValue = newValue
        }
    }

    private var selectedDestinationBinding: Binding<SidebarDestination?> {
        Binding {
            selectedDestination
        } set: { destination in
            if destination != selectedDestination {
                closeAlbum()
            }

            selectedDestination = destination
        }
    }

    private var sidebarVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding {
            .all
        } set: { _ in
            _sidebarVisibility.wrappedValue = .all
        }
    }

    private var playbackErrorMessage: String? {
        get {
            _playbackErrorMessage.wrappedValue
        }
        nonmutating set {
            _playbackErrorMessage.wrappedValue = newValue
        }
    }

    private var isPlaybackErrorPresented: Binding<Bool> {
        Binding {
            playbackErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                playbackErrorMessage = nil
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibilityBinding) {
            SidebarView(selection: selectedDestinationBinding)
        } detail: {
            detailArea
        }
        .background(SidebarSplitCollapseGuard(minimumThickness: SidebarLayout.minimumWidth))
        .alert(
            "Playback Failed",
            isPresented: isPlaybackErrorPresented
        ) {
            Button("OK", role: .cancel) {
                playbackErrorMessage = nil
            }
        } message: {
            Text(playbackErrorMessage ?? "Playback could not start.")
        }
    }

    private var detailArea: some View {
        ZStack(alignment: .bottom) {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let appState = optionalAppState {
                MiniPlayerView(onAlbumArtworkPressed: showPlaybackAlbum)
                    .environmentObject(appState)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder
    private var detailView: some View {
        ZStack {
            destinationView
                .opacity(selectedAlbum == nil ? 1 : 0)
                .allowsHitTesting(selectedAlbum == nil)
                .accessibilityHidden(selectedAlbum != nil)

            if let selectedAlbum {
                albumDetailView(summary: selectedAlbum)
            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selectedDestination ?? .search {
        case .search:
            if let appState = optionalAppState {
                SearchDetailView(
                    searchViewModel: appState.searchViewModel,
                    onOpenAlbum: openAlbum
                )
            } else {
                MissingAppStateView()
            }
        case .favorites, .favoriteAlbums, .favoriteSongs:
            if let appState = optionalAppState {
                FavoritesView(
                    onOpenAlbum: { album in
                        openAlbum(album)
                    },
                    category: favoriteCategory,
                    onPlayTrack: { entry, entries in
                        playFavoriteTrack(entry, in: entries)
                    }
                )
                    .environmentObject(appState)
            } else {
                MissingAppStateView()
            }
        case .history:
            if let appState = optionalAppState {
                HistoryView(
                    onPlayTrack: { entry, entries in
                        playHistoryTrack(entry, in: entries)
                    }
                )
                    .environmentObject(appState)
            } else {
                MissingAppStateView()
            }
        case .settings:
            if let appState = optionalAppState {
                SettingsView()
                    .environmentObject(appState)
            } else {
                MissingAppStateView()
            }
        }
    }

    @ViewBuilder
    private func albumDetailView(summary: AlbumSummary) -> some View {
        if let appState = optionalAppState {
            AlbumDetailView(
                summary: summary,
                client: appState.client,
                libraryStore: appState.libraryStore,
                artworkCache: appState.artworkCache,
                playbackEngine: appState.playbackEngine,
                onBack: closeAlbum,
                onPlay: play
            )
            .id(summary.id)
        } else {
            MissingAppStateView()
        }
    }

    private func openAlbum(_ album: AlbumSummary) {
        playbackErrorMessage = nil
        selectedAlbum = album
    }

    private func closeAlbum() {
        playbackErrorMessage = nil
        selectedAlbum = nil
    }

    private func showPlaybackAlbum(_ album: AlbumDetail) {
        guard selectedDestination != .search || selectedAlbum?.id != album.id else {
            return
        }

        selectedDestination = .search
        selectedAlbum = album.summary
    }

    private var favoriteCategory: FavoriteCategory {
        selectedDestination == .favoriteSongs ? .songs : .albums
    }

    private func playFavoriteTrack(_ entry: FavoriteTrackEntry, in entries: [FavoriteTrackEntry]) {
        guard let appState = optionalAppState else {
            playbackErrorMessage = "App state is unavailable."
            return
        }

        let playbackItems = FavoritePlaybackContext.playbackItems(from: entries)

        guard let startingItem = FavoritePlaybackContext.startingItem(
            in: playbackItems,
            selectedTrackID: entry.id
        ) else {
            playbackErrorMessage = "This favorite song is missing playback metadata."
            return
        }

        playbackErrorMessage = nil

        Task { @MainActor in
            do {
                try await appState.playbackEngine.play(
                    items: playbackItems,
                    startingAt: startingItem
                )

                do {
                    try appState.libraryStore.recordPlay(
                        album: startingItem.album,
                        track: startingItem.track
                    )
                } catch {
                    // History is local convenience state; playback should not fail for it.
                }
            } catch is CancellationError {
                // A newer playback request superseded this one.
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }

    private func playHistoryTrack(_ entry: HistoryEntry, in entries: [HistoryEntry]) {
        guard let appState = optionalAppState else {
            playbackErrorMessage = "App state is unavailable."
            return
        }

        let playbackItems = HistoryPlaybackContext.playbackItems(from: entries)

        guard let startingItem = HistoryPlaybackContext.startingItem(
            in: playbackItems,
            selectedTrackID: entry.id
        ) else {
            playLegacyHistoryTrack(entry)
            return
        }

        playbackErrorMessage = nil

        Task { @MainActor in
            do {
                try await appState.playbackEngine.play(
                    items: playbackItems,
                    startingAt: startingItem
                )

                do {
                    try appState.libraryStore.recordPlay(
                        album: startingItem.album,
                        track: startingItem.track
                    )
                } catch {
                    // History is local convenience state; playback should not fail for it.
                }
            } catch is CancellationError {
                // A newer playback request superseded this one.
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }

    private func playLegacyHistoryTrack(_ entry: HistoryEntry) {
        guard let appState = optionalAppState else {
            playbackErrorMessage = "App state is unavailable."
            return
        }

        playbackErrorMessage = nil

        Task { @MainActor in
            do {
                let album = try await loadHistoryAlbum(for: entry, appState: appState)

                guard let track = album.tracks.first(where: { $0.id == entry.id }) else {
                    playbackErrorMessage = "This history song is missing playback metadata."
                    return
                }

                try await appState.playbackEngine.play(
                    album: album,
                    startingAt: track
                )

                do {
                    try appState.libraryStore.recordPlay(album: album, track: track)
                } catch {
                    // History is local convenience state; playback should not fail for it.
                }
            } catch is CancellationError {
                // A newer playback request superseded this one.
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }

    private func loadHistoryAlbum(for entry: HistoryEntry, appState: AppState) async throws -> AlbumDetail {
        if let cachedAlbum = try appState.libraryStore.cachedFavoriteAlbumDetail(albumID: entry.albumID) {
            return cachedAlbum
        }

        let albumURL = entry.albumURL ?? legacyHistoryAlbumURL(albumID: entry.albumID)
        let html = try await appState.client.html(from: albumURL)
        return try AlbumPageParser.parse(html: html, url: albumURL)
    }

    private func legacyHistoryAlbumURL(albumID: String) -> URL {
        KHRequestBuilder.baseURL
            .appendingPathComponent("game-soundtracks")
            .appendingPathComponent("album")
            .appendingPathComponent(albumID)
    }

    private func play(album: AlbumDetail, track: Track) {
        guard let appState = optionalAppState else {
            playbackErrorMessage = "App state is unavailable."
            return
        }

        playbackErrorMessage = nil

        Task { @MainActor in
            do {
                try await appState.playbackEngine.play(
                    album: album,
                    startingAt: track
                )

                do {
                    try appState.libraryStore.recordPlay(album: album, track: track)
                } catch {
                    // History is local convenience state; playback should not fail for it.
                }
            } catch is CancellationError {
                // A newer playback request superseded this one.
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct SearchDetailView: View {
    private let searchViewModel: SearchViewModel
    private let onOpenAlbum: (AlbumSummary) -> Void

    init(searchViewModel: SearchViewModel, onOpenAlbum: @escaping (AlbumSummary) -> Void) {
        self.searchViewModel = searchViewModel
        self.onOpenAlbum = onOpenAlbum
    }

    var body: some View {
        SearchView(viewModel: searchViewModel) { album in
            onOpenAlbum(album)
        }
    }
}

private struct MissingAppStateView: View {
    var body: some View {
        ContentUnavailableView(
            "App State Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text("Restart the app to try again.")
        )
    }
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
