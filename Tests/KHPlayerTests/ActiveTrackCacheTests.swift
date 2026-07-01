import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. These helpers document the
// intended ActiveTrackCache checks without importing a test framework.
internal struct ActiveTrackCacheTests {
    internal func limitBelowChunkSizeThrowsCacheLimitTooSmall() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

        do {
            _ = try ActiveTrackCache(directory: directory, limitBytes: 3, chunkSize: 4)
            preconditionFailure("Expected KHError.cacheLimitTooSmall for a limit below chunk size.")
        } catch KHError.cacheLimitTooSmall {
        }
    }

    internal func writingChunksRespectsLimitAndEvictsLeastRecentlyUsedChunk() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)
        try cache.prepareForTrack(cacheKey: "track-a")

        try cache.store(data: Data([0, 1, 2, 3]), rangeStart: 0)
        try cache.store(data: Data([4, 5, 6, 7]), rangeStart: 4)
        try cache.store(data: Data([8, 9, 10, 11]), rangeStart: 8)

        let size = try cache.currentSize()
        let evictedChunk = try cache.data(for: 0..<4)
        let firstPreservedChunk = try cache.data(for: 4..<8)
        let secondPreservedChunk = try cache.data(for: 8..<12)

        precondition(size <= 8)
        precondition(evictedChunk == nil)
        precondition(firstPreservedChunk == Data([4, 5, 6, 7]))
        precondition(secondPreservedChunk == Data([8, 9, 10, 11]))
    }

    internal func prepareForNewTrackClearsOldChunks() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)
        try cache.prepareForTrack(cacheKey: "track-a")
        try cache.store(data: Data([0, 1, 2, 3]), rangeStart: 0)

        try cache.prepareForTrack(cacheKey: "track-b")

        let size = try cache.currentSize()
        let oldChunk = try cache.data(for: 0..<4)

        precondition(size == 0)
        precondition(oldChunk == nil)
    }

    internal func rangeSpanningMultipleCachedChunksCanBeRead() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 16, chunkSize: 4)
        try cache.prepareForTrack(cacheKey: "track-a")
        try cache.store(data: Data([0, 1, 2, 3, 4, 5, 6, 7]), rangeStart: 0)

        let spanningData = try cache.data(for: 2..<6)
        precondition(spanningData == Data([2, 3, 4, 5]))
    }

    internal func rangeReturnsNilWhenAnyChunkIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 16, chunkSize: 4)
        try cache.prepareForTrack(cacheKey: "track-a")
        try cache.store(data: Data([0, 1, 2, 3]), rangeStart: 0)
        try cache.store(data: Data([8, 9, 10, 11]), rangeStart: 8)

        let missingData = try cache.data(for: 0..<12)
        precondition(missingData == nil)
    }
}
