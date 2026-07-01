import Foundation

@main
private struct ArtworkCacheBehaviorChecks {
    static func main() async throws {
        try await checkArtworkCacheStoresAndRemovesAlbumArtwork()
    }

    private static func checkArtworkCacheStoresAndRemovesAlbumArtwork() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = ArtworkCache(directory: directory)
        let sourceURL = URL(string: "https://nu.vgmtreasurechest.com/soundtracks/persona/folder.png")!
        let cachedURL = try await cache.storeArtworkData(
            Data([0x70, 0x6e, 0x67]),
            albumID: albumID,
            sourceURL: sourceURL
        )

        precondition(cachedURL.isFileURL)
        precondition(cachedURL.pathExtension == "png")
        precondition(FileManager.default.fileExists(atPath: cachedURL.path))
        let storedData = try Data(contentsOf: cachedURL)
        precondition(storedData == Data([0x70, 0x6e, 0x67]))

        try await cache.removeArtwork(albumID: albumID)
        precondition(!FileManager.default.fileExists(atPath: cachedURL.path))
    }

    private static let albumID = "persona-vinyl-soundtrack-2022"
}
