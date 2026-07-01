import Foundation

private final class DelayedStreamResolver: StreamResolving {
    func resolve(track: Track) async throws -> ResolvedStream {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        throw CancellationError()
    }
}

@main
private struct PlaybackResponsivenessBehaviorChecks {
    @MainActor
    static func main() async throws {
        try await checkPlaybackSelectionUpdatesBeforeStreamResolution()
    }

    @MainActor
    private static func checkPlaybackSelectionUpdatesBeforeStreamResolution() async throws {
        let track = Track(
            id: "album-1-track-1",
            albumID: "album-1",
            discNumber: nil,
            number: 1,
            title: "Opening",
            detailURL: URL(string: "https://example.com/opening")!,
            duration: 120,
            mp3Size: "3 MB"
        )
        let album = AlbumDetail(
            id: "album-1",
            title: "Album One",
            url: URL(string: "https://example.com/album-1")!,
            alternativeTitles: [],
            platforms: [],
            year: nil,
            publisher: nil,
            albumType: nil,
            fileCount: 1,
            totalDuration: 120,
            totalMP3Size: "3 MB",
            dateAdded: nil,
            artworkURL: nil,
            description: nil,
            tracks: [track]
        )
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(
            directory: cacheDirectory,
            limitBytes: 1024 * 1024,
            chunkSize: 64 * 1024
        )
        let engine = PlaybackEngine(
            resolver: DelayedStreamResolver(),
            cache: cache
        )

        let playTask = Task { @MainActor in
            try await engine.play(
                album: album,
                startingAt: track
            )
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        precondition(engine.currentItem?.album.id == album.id)
        precondition(engine.currentItem?.track.id == track.id)
        precondition(engine.elapsedTime == 0)
        precondition(engine.duration == track.duration)
        precondition(!engine.isPlaying)

        playTask.cancel()
        do {
            try await playTask.value
        } catch is CancellationError {
        }
    }
}
