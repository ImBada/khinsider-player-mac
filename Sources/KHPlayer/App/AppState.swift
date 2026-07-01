import Combine
import Foundation

@MainActor
internal final class AppState: ObservableObject {
    private static let defaultCacheLimitBytes: Int64 = 256 * 1024 * 1024

    internal let client: KHClient
    internal let streamResolver: StreamResolver
    internal let libraryStore: LibraryStore
    internal let artworkCache: ArtworkCache
    internal let searchViewModel: SearchViewModel

    @Published internal private(set) var cacheLimitBytes: Int64 = 256 * 1024 * 1024
    @Published internal private(set) var playbackEngine: PlaybackEngine

    private var activeTrackCache: ActiveTrackCache

    internal init() throws {
        let client = KHClient()
        let streamResolver = StreamResolver(client: client)
        let libraryStore = try LibraryStore.appStore()
        let artworkCache = try ArtworkCache.appCache()
        let cache = try Self.makeActiveTrackCache(limitBytes: Self.defaultCacheLimitBytes)
        try cache.clear()
        let playbackEngine = PlaybackEngine(resolver: streamResolver, cache: cache)

        self.client = client
        self.streamResolver = streamResolver
        self.libraryStore = libraryStore
        self.artworkCache = artworkCache
        self.searchViewModel = SearchViewModel(client: client)
        self.activeTrackCache = cache
        self.playbackEngine = playbackEngine
    }

    internal func setCacheLimitBytes(_ limitBytes: Int64) async throws {
        guard limitBytes != cacheLimitBytes else {
            return
        }

        let cache = try Self.makeActiveTrackCache(limitBytes: limitBytes)
        self.playbackEngine.stop()
        try cache.clear()

        let playbackEngine = PlaybackEngine(resolver: streamResolver, cache: cache)

        activeTrackCache = cache
        self.playbackEngine = playbackEngine
        cacheLimitBytes = limitBytes
    }

    private static func makeActiveTrackCache(limitBytes: Int64) throws -> ActiveTrackCache {
        try ActiveTrackCache(
            directory: activeTrackCacheDirectory(),
            limitBytes: limitBytes
        )
    }

    private static func activeTrackCacheDirectory() throws -> URL {
        let cachesURL = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return cachesURL
            .appendingPathComponent("com.bada.khinsider-player-mac", isDirectory: true)
            .appendingPathComponent("ActiveTrackCache", isDirectory: true)
    }
}
