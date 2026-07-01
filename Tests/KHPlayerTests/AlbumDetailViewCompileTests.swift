import SwiftUI

@testable import KHPlayer

// Compile-only helpers for the native album detail screen. XCTest and Swift
// Testing are unavailable in the local CommandLineTools environment.
internal struct AlbumDetailViewCompileTests {
    @MainActor
    internal func albumDetailViewModelExposesInitialLoadState() {
        let model = AlbumDetailViewModel(
            summary: Self.albumSummary,
            client: KHClient(),
            libraryStore: try! LibraryStore.inMemory()
        )

        precondition(model.album == nil)
        precondition(!model.isLoading)
        precondition(model.errorMessage == nil)
        precondition(!model.isAlbumFavorite)
        precondition(model.favoriteTrackIDs.isEmpty)
    }

    @MainActor
    internal func albumDetailViewAcceptsOwnedViewModelAndPlayHandler() throws {
        _ = AlbumDetailView(
            summary: Self.albumSummary,
            client: KHClient(),
            libraryStore: try LibraryStore.inMemory(),
            playbackEngine: try Self.playbackEngine(),
            onBack: {}
        ) { album, track in
            precondition(album.id == track.albumID)
        }
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

    @MainActor
    private static func playbackEngine() throws -> PlaybackEngine {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)

        return PlaybackEngine(
            resolver: StreamResolver(client: KHClient()),
            cache: cache
        )
    }
}
