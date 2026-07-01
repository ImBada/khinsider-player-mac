import Foundation

internal actor ArtworkCache {
    private let directory: URL
    private let session: URLSession

    internal init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
    }

    internal static func appCache() throws -> ArtworkCache {
        let fileManager = FileManager.default
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = applicationSupportURL
            .appendingPathComponent("KHInsiderPlayerMac", isDirectory: true)
            .appendingPathComponent("ArtworkCache", isDirectory: true)

        return ArtworkCache(directory: directoryURL)
    }

    internal func cacheArtwork(from sourceURL: URL?, albumID: String) async throws -> URL? {
        guard let sourceURL else {
            return nil
        }

        let (data, response) = try await session.data(from: sourceURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw KHError.networkStatus(httpResponse.statusCode)
        }

        return try storeArtworkData(data, albumID: albumID, sourceURL: sourceURL)
    }

    internal func storeArtworkData(
        _ data: Data,
        albumID: String,
        sourceURL: URL
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try removeArtwork(albumID: albumID)

        let fileURL = localArtworkURL(albumID: albumID, sourceURL: sourceURL)
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    internal func removeArtwork(albumID: String) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        let prefix = sanitizedAlbumID(albumID) + "."
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        for fileURL in files where fileURL.lastPathComponent.hasPrefix(prefix) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func localArtworkURL(albumID: String, sourceURL: URL) -> URL {
        directory.appendingPathComponent(
            sanitizedAlbumID(albumID) + "." + fileExtension(for: sourceURL),
            isDirectory: false
        )
    }

    private func sanitizedAlbumID(_ albumID: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = albumID.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }

        return String(scalars)
    }

    private func fileExtension(for sourceURL: URL) -> String {
        let pathExtension = sourceURL.pathExtension.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return pathExtension.isEmpty ? "image" : pathExtension.lowercased()
    }
}
