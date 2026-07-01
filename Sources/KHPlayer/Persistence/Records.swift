import Foundation
import GRDB

struct HistoryEntry: FetchableRecord, PersistableRecord, Equatable, Identifiable {
    static let databaseTableName = "history"

    var trackID: String
    var albumID: String
    var title: String
    var playedAt: Date
    var albumTitle: String?
    var detailURL: URL?
    var albumURL: URL?
    var artworkURL: URL?
    var duration: TimeInterval?

    var id: String {
        trackID
    }

    init(
        trackID: String,
        albumID: String,
        title: String,
        playedAt: Date,
        albumTitle: String? = nil,
        detailURL: URL? = nil,
        albumURL: URL? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval? = nil
    ) {
        self.trackID = trackID
        self.albumID = albumID
        self.title = title
        self.playedAt = playedAt
        self.albumTitle = albumTitle
        self.detailURL = detailURL
        self.albumURL = albumURL
        self.artworkURL = artworkURL
        self.duration = duration
    }

    init(row: Row) throws {
        trackID = row["trackID"]
        albumID = row["albumID"]
        title = row["title"]
        playedAt = row["playedAt"]
        albumTitle = row["albumTitle"]
        detailURL = Self.url(from: row["detailURL"])
        albumURL = Self.url(from: row["albumURL"])
        artworkURL = Self.url(from: row["artworkURL"])
        duration = row["duration"]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container["trackID"] = trackID
        container["albumID"] = albumID
        container["title"] = title
        container["playedAt"] = playedAt
        container["albumTitle"] = albumTitle
        container["detailURL"] = detailURL?.absoluteString
        container["albumURL"] = albumURL?.absoluteString
        container["artworkURL"] = artworkURL?.absoluteString
        container["duration"] = duration
    }

    private static func url(from value: String?) -> URL? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return URL(string: value)
    }
}

struct FavoriteAlbumEntry: FetchableRecord, Equatable, Identifiable {
    var id: String
    var title: String
    var url: URL?
    var artworkURL: URL?
    var localArtworkURL: URL?
    var year: Int?
    var albumType: String?
    var createdAt: Date

    init(row: Row) throws {
        id = row["albumID"]
        title = row["title"] ?? id
        url = Self.url(from: row["url"])
        artworkURL = Self.url(from: row["artworkURL"])
        localArtworkURL = Self.url(from: row["localArtworkURL"])
        year = row["year"]
        albumType = row["albumType"]
        createdAt = row["createdAt"]
    }

    private static func url(from value: String?) -> URL? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return URL(string: value)
    }
}

struct FavoriteTrackEntry: FetchableRecord, Equatable, Identifiable {
    var id: String
    var albumID: String
    var title: String
    var albumTitle: String
    var detailURL: URL?
    var albumURL: URL?
    var artworkURL: URL?
    var localArtworkURL: URL?
    var duration: TimeInterval?
    var createdAt: Date

    init(row: Row) throws {
        id = row["trackID"]
        albumID = row["albumID"]
        title = row["title"] ?? id
        albumTitle = row["albumTitle"] ?? albumID
        detailURL = Self.url(from: row["detailURL"])
        albumURL = Self.url(from: row["albumURL"])
        artworkURL = Self.url(from: row["artworkURL"])
        localArtworkURL = Self.url(from: row["localArtworkURL"])
        duration = row["duration"]
        createdAt = row["createdAt"]
    }

    private static func url(from value: String?) -> URL? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return URL(string: value)
    }
}
