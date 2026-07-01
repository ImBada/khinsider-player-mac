import Foundation

@main
struct PlaybackCacheBehaviorChecks {
    static func main() throws {
        try checkRangedResponsePolicy()
        try checkRangeFetchDoesNotUseFullBodyDataTask()
        try checkPlaybackAttemptClearsCacheBeforeResolvingStream()
        try checkPlaybackEnginePrefetchesNextTrack()
        try checkActiveTrackCacheClear()
    }

    private static func checkRangedResponsePolicy() throws {
        precondition(!CachingStreamResourceLoader.acceptsRangedResponse(statusCode: 200))
        precondition(CachingStreamResourceLoader.acceptsRangedResponse(statusCode: 206))
        precondition(!CachingStreamResourceLoader.acceptsRangedResponse(statusCode: 416))
    }

    private static func checkRangeFetchDoesNotUseFullBodyDataTask() throws {
        let sourceURL = URL(fileURLWithPath: "Sources/KHPlayer/Playback/CachingStreamResourceLoader.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        precondition(!source.contains("session.data(for: request)"))
        precondition(source.contains("session.bytes(for: request)"))
    }

    private static func checkPlaybackAttemptClearsCacheBeforeResolvingStream() throws {
        let sourceURL = URL(fileURLWithPath: "Sources/KHPlayer/Playback/PlaybackEngine.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        guard let attemptStart = source.range(of: "private func beginPlaybackAttempt"),
              let nextFunction = source.range(of: "private func ensureCurrentPlayback", range: attemptStart.upperBound..<source.endIndex) else {
            preconditionFailure("PlaybackEngine.beginPlaybackAttempt was not found")
        }

        let attemptBody = source[attemptStart.lowerBound..<nextFunction.lowerBound]
        precondition(attemptBody.contains("try cache.clear()"))
    }

    private static func checkPlaybackEnginePrefetchesNextTrack() throws {
        let sourceURL = URL(fileURLWithPath: "Sources/KHPlayer/Playback/PlaybackEngine.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        precondition(source.contains("private struct PrefetchedTrack"))
        precondition(source.contains("private var prefetchTask: Task<Void, Never>?"))
        precondition(source.contains("private var prefetchedTrack: PrefetchedTrack?"))
        precondition(source.contains("try await playPrefetchedTrack("))
        precondition(source.contains("startPrefetchForNextItem(after: generation)"))
        precondition(source.contains("private func startPrefetchForNextItem(after generation: Int)"))
        precondition(source.contains("private func cancelPrefetch(deleteFile: Bool)"))
        precondition(source.contains("URLSession.shared.bytes(from: stream.sourceURL)"))
        precondition(source.contains("FileManager.default.replaceItemAt("))
    }

    private static func checkActiveTrackCacheClear() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)
        try cache.store(data: Data([1, 2, 3, 4]), rangeStart: 0)

        let sizeBeforeClear = try cache.currentSize()
        precondition(sizeBeforeClear == 4)

        try cache.clear()

        let sizeAfterClear = try cache.currentSize()
        let filesAfterClear = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        precondition(sizeAfterClear == 0)
        precondition(filesAfterClear.isEmpty)
    }
}
