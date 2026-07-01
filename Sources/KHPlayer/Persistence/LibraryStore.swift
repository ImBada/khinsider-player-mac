import Foundation
import GRDB

final class LibraryStore {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try SchemaMigrator.migrator.migrate(dbQueue)
    }

    static func inMemory() throws -> LibraryStore {
        try LibraryStore(dbQueue: DatabaseQueue())
    }

    static func appStore() throws -> LibraryStore {
        let fileManager = FileManager.default
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = applicationSupportURL.appendingPathComponent(
            "KHInsiderPlayerMac",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let databaseURL = directoryURL.appendingPathComponent("Library.sqlite")

        return try LibraryStore(dbQueue: DatabaseQueue(path: databaseURL.path))
    }

    func setAlbumFavorite(album: AlbumSummary, isFavorite: Bool) throws {
        try dbQueue.write { db in
            if isFavorite {
                try upsertFavoriteAlbum(album, in: db)
            } else {
                try db.execute(
                    sql: "DELETE FROM favorite_albums WHERE albumID = ?",
                    arguments: [album.id]
                )
                try removeCachedAlbumDetailIfUnreferenced(albumID: album.id, in: db)
            }
        }
    }

    func setAlbumFavorite(album: AlbumDetail, isFavorite: Bool) throws {
        try dbQueue.write { db in
            if isFavorite {
                try upsertFavoriteAlbum(favoriteSummary(for: album), in: db)
                try upsertFavoriteAlbumDetail(album, in: db)
            } else {
                try db.execute(
                    sql: "DELETE FROM favorite_albums WHERE albumID = ?",
                    arguments: [album.id]
                )
                try removeCachedAlbumDetailIfUnreferenced(albumID: album.id, in: db)
            }
        }
    }

    func isAlbumFavorite(albumID: String) throws -> Bool {
        try dbQueue.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM favorite_albums WHERE albumID = ?",
                arguments: [albumID]
            ) ?? 0

            return count > 0
        }
    }

    func favoriteAlbums() throws -> [FavoriteAlbumEntry] {
        try dbQueue.read { db in
            try FavoriteAlbumEntry.fetchAll(
                db,
                sql: """
                SELECT albumID, title, url, artworkURL, localArtworkURL, year, albumType, createdAt
                FROM favorite_albums
                ORDER BY createdAt DESC, albumID ASC
                """
            )
        }
    }

    func storeFavoriteAlbumDetail(_ album: AlbumDetail) throws {
        try dbQueue.write { db in
            try upsertFavoriteAlbumDetail(album, in: db)
        }
    }

    func cachedFavoriteAlbumDetail(albumID: String) throws -> AlbumDetail? {
        try dbQueue.read { db in
            guard try favoriteReferenceCount(albumID: albumID, in: db) > 0 else {
                return nil
            }

            guard let detailJSON = try String.fetchOne(
                db,
                sql: "SELECT detailJSON FROM favorite_album_details WHERE albumID = ?",
                arguments: [albumID]
            ) else {
                return nil
            }

            return try Self.decodeFavoriteAlbumDetail(from: detailJSON)
        }
    }

    func setTrackFavorite(album: AlbumDetail, track: Track, isFavorite: Bool) throws {
        try dbQueue.write { db in
            if isFavorite {
                try upsertFavoriteAlbumDetail(album, in: db)
                try db.execute(
                    sql: """
                    INSERT INTO favorite_tracks (
                        trackID,
                        albumID,
                        title,
                        albumTitle,
                        detailURL,
                        albumURL,
                        artworkURL,
                        duration,
                        createdAt
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(trackID) DO UPDATE SET
                        albumID = excluded.albumID,
                        title = excluded.title,
                        albumTitle = excluded.albumTitle,
                        detailURL = excluded.detailURL,
                        albumURL = excluded.albumURL,
                        artworkURL = excluded.artworkURL,
                        duration = excluded.duration
                    """,
                    arguments: [
                        track.id,
                        album.id,
                        track.title,
                        album.title,
                        track.detailURL.absoluteString,
                        album.url.absoluteString,
                        album.artworkURL?.absoluteString,
                        track.duration,
                        Date()
                    ]
                )
            } else {
                try db.execute(
                    sql: "DELETE FROM favorite_tracks WHERE trackID = ?",
                    arguments: [track.id]
                )
                try removeCachedAlbumDetailIfUnreferenced(albumID: album.id, in: db)
            }
        }
    }

    func isTrackFavorite(trackID: String) throws -> Bool {
        try dbQueue.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM favorite_tracks WHERE trackID = ?",
                arguments: [trackID]
            ) ?? 0

            return count > 0
        }
    }

    func favoriteTracks() throws -> [FavoriteTrackEntry] {
        try dbQueue.read { db in
            try FavoriteTrackEntry.fetchAll(
                db,
                sql: """
                SELECT trackID, albumID, title, albumTitle, detailURL, albumURL, artworkURL, localArtworkURL, duration, createdAt
                FROM favorite_tracks
                ORDER BY createdAt DESC, trackID ASC
                """
            )
        }
    }

    func updateFavoriteArtwork(
        albumID: String,
        remoteArtworkURL: URL?,
        localArtworkURL: URL
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE favorite_albums
                SET artworkURL = ?, localArtworkURL = ?
                WHERE albumID = ?
                """,
                arguments: [
                    remoteArtworkURL?.absoluteString,
                    localArtworkURL.absoluteString,
                    albumID
                ]
            )
            try db.execute(
                sql: """
                UPDATE favorite_tracks
                SET artworkURL = ?, localArtworkURL = ?
                WHERE albumID = ?
                """,
                arguments: [
                    remoteArtworkURL?.absoluteString,
                    localArtworkURL.absoluteString,
                    albumID
                ]
            )
        }
    }

    func hasFavoriteReference(albumID: String) throws -> Bool {
        try dbQueue.read { db in
            let albumCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM favorite_albums WHERE albumID = ?",
                arguments: [albumID]
            ) ?? 0
            let trackCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM favorite_tracks WHERE albumID = ?",
                arguments: [albumID]
            ) ?? 0

            return albumCount + trackCount > 0
        }
    }

    func recordPlay(trackID: String, albumID: String, title: String) throws {
        try recordPlay(
            trackID: trackID,
            albumID: albumID,
            title: title,
            albumTitle: nil,
            detailURL: nil,
            albumURL: nil,
            artworkURL: nil,
            duration: nil
        )
    }

    func recordPlay(album: AlbumDetail, track: Track) throws {
        try recordPlay(
            trackID: track.id,
            albumID: album.id,
            title: track.title,
            albumTitle: album.title,
            detailURL: track.detailURL,
            albumURL: album.url,
            artworkURL: album.artworkURL,
            duration: track.duration
        )
    }

    private func recordPlay(
        trackID: String,
        albumID: String,
        title: String,
        albumTitle: String?,
        detailURL: URL?,
        albumURL: URL?,
        artworkURL: URL?,
        duration: TimeInterval?
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO history (
                    trackID,
                    albumID,
                    title,
                    playedAt,
                    albumTitle,
                    detailURL,
                    albumURL,
                    artworkURL,
                    duration
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(trackID) DO UPDATE SET
                    albumID = excluded.albumID,
                    title = excluded.title,
                    playedAt = excluded.playedAt,
                    albumTitle = excluded.albumTitle,
                    detailURL = excluded.detailURL,
                    albumURL = excluded.albumURL,
                    artworkURL = excluded.artworkURL,
                    duration = excluded.duration
                """,
                arguments: [
                    trackID,
                    albumID,
                    title,
                    Date(),
                    albumTitle,
                    detailURL?.absoluteString,
                    albumURL?.absoluteString,
                    artworkURL?.absoluteString,
                    duration
                ]
            )
        }
    }

    func recentHistory(limit: Int) throws -> [HistoryEntry] {
        guard limit > 0 else {
            return []
        }

        return try dbQueue.read { db in
            try HistoryEntry.fetchAll(
                db,
                sql: """
                SELECT
                    trackID,
                    albumID,
                    title,
                    playedAt,
                    albumTitle,
                    detailURL,
                    albumURL,
                    artworkURL,
                    duration
                FROM history
                ORDER BY playedAt DESC, ROWID DESC
                LIMIT ?
                """,
                arguments: [limit]
            )
        }
    }

    private func upsertFavoriteAlbum(_ album: AlbumSummary, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO favorite_albums (
                albumID,
                title,
                url,
                artworkURL,
                year,
                albumType,
                createdAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(albumID) DO UPDATE SET
                title = excluded.title,
                url = excluded.url,
                artworkURL = excluded.artworkURL,
                year = excluded.year,
                albumType = excluded.albumType
            """,
            arguments: [
                album.id,
                album.title,
                album.url.absoluteString,
                album.artworkURL?.absoluteString,
                album.year,
                album.albumType,
                Date()
            ]
        )
    }

    private func upsertFavoriteAlbumDetail(_ album: AlbumDetail, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO favorite_album_details (
                albumID,
                detailJSON,
                updatedAt
            )
            VALUES (?, ?, ?)
            ON CONFLICT(albumID) DO UPDATE SET
                detailJSON = excluded.detailJSON,
                updatedAt = excluded.updatedAt
            """,
            arguments: [
                album.id,
                try Self.encodeFavoriteAlbumDetail(album),
                Date()
            ]
        )
    }

    private func removeCachedAlbumDetailIfUnreferenced(albumID: String, in db: Database) throws {
        guard try favoriteReferenceCount(albumID: albumID, in: db) == 0 else {
            return
        }

        try db.execute(
            sql: "DELETE FROM favorite_album_details WHERE albumID = ?",
            arguments: [albumID]
        )
    }

    private func favoriteReferenceCount(albumID: String, in db: Database) throws -> Int {
        let albumCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM favorite_albums WHERE albumID = ?",
            arguments: [albumID]
        ) ?? 0
        let trackCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM favorite_tracks WHERE albumID = ?",
            arguments: [albumID]
        ) ?? 0

        return albumCount + trackCount
    }

    private func favoriteSummary(for album: AlbumDetail) -> AlbumSummary {
        AlbumSummary(
            id: album.id,
            title: album.title,
            url: album.url,
            artworkURL: album.artworkURL,
            platforms: album.platforms,
            albumType: album.albumType,
            year: album.year,
            catalogNumber: nil
        )
    }

    private static func encodeFavoriteAlbumDetail(_ album: AlbumDetail) throws -> String {
        let data = try JSONEncoder().encode(album)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeFavoriteAlbumDetail(from detailJSON: String) throws -> AlbumDetail {
        let data = Data(detailJSON.utf8)
        return try JSONDecoder().decode(AlbumDetail.self, from: data)
    }
}
