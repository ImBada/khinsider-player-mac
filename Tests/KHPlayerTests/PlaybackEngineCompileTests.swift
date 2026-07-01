import Foundation

@testable import KHPlayer

// Compile-only helpers for PlaybackEngine integration behavior in the local
// CommandLineTools environment, where XCTest and Swift Testing are unavailable.
internal struct PlaybackEngineCompileTests {
    @MainActor
    internal func playbackEngineCanBeStoppedBeforeCacheReuse() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)
        let engine = PlaybackEngine(
            resolver: StreamResolver(client: KHClient()),
            cache: cache
        )

        engine.stop()

        precondition(engine.currentItem == nil)
        precondition(!engine.isPlaying)
    }

    internal func streamResourceLoaderCanBeCancelledBeforeCacheReuse() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)
        let loader = CachingStreamResourceLoader(
            sourceURL: URL(string: "https://example.com/track.mp3")!,
            cache: cache
        )

        loader.cancel()
    }
}
