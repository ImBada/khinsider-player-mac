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
    internal let releaseChecker: GitHubReleaseChecker
    internal let appUpdater: AppUpdater

    @Published internal private(set) var cacheLimitBytes: Int64 = 256 * 1024 * 1024
    @Published internal private(set) var playbackEngine: PlaybackEngine
    @Published internal private(set) var updateAvailability: UpdateAvailability?

    private var activeTrackCache: ActiveTrackCache
    private var hasCheckedForUpdates = false

    internal init() throws {
        let client = KHClient()
        let releaseChecker = GitHubReleaseChecker()
        let appUpdater = AppUpdater()
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
        self.releaseChecker = releaseChecker
        self.appUpdater = appUpdater
        self.activeTrackCache = cache
        self.playbackEngine = playbackEngine
    }

    internal func checkForUpdatesIfNeeded() async {
        guard !hasCheckedForUpdates else {
            return
        }

        hasCheckedForUpdates = true

        do {
            let availability = try await releaseChecker.updateAvailability(
                currentVersion: Self.currentAppVersion()
            )
            updateAvailability = availability.isUpdateAvailable ? availability : nil
        } catch {
            updateAvailability = nil
        }
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

    internal func checkForUpdates() {
        appUpdater.checkForUpdates()
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

    private static func currentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}
