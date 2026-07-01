import Foundation

internal struct AlbumSummary: Identifiable, Equatable, Codable, Sendable {
    internal let id: String
    internal let title: String
    internal let url: URL
    internal let artworkURL: URL?
    internal let platforms: [String]
    internal let albumType: String?
    internal let year: Int?
    internal let catalogNumber: String?

    internal init(
        id: String,
        title: String,
        url: URL,
        artworkURL: URL?,
        platforms: [String],
        albumType: String?,
        year: Int?,
        catalogNumber: String?
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.artworkURL = artworkURL
        self.platforms = platforms
        self.albumType = albumType
        self.year = year
        self.catalogNumber = catalogNumber
    }
}

internal struct AlbumDetail: Identifiable, Equatable, Codable, Sendable {
    internal let id: String
    internal let title: String
    internal let url: URL
    internal let alternativeTitles: [String]
    internal let platforms: [String]
    internal let year: Int?
    internal let publisher: String?
    internal let albumType: String?
    internal let fileCount: Int?
    internal let totalDuration: TimeInterval?
    internal let totalMP3Size: String?
    internal let dateAdded: String?
    internal let artworkURL: URL?
    internal let description: String?
    internal let tracks: [Track]

    internal init(
        id: String,
        title: String,
        url: URL,
        alternativeTitles: [String],
        platforms: [String],
        year: Int?,
        publisher: String?,
        albumType: String?,
        fileCount: Int?,
        totalDuration: TimeInterval?,
        totalMP3Size: String?,
        dateAdded: String?,
        artworkURL: URL?,
        description: String?,
        tracks: [Track]
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.alternativeTitles = alternativeTitles
        self.platforms = platforms
        self.year = year
        self.publisher = publisher
        self.albumType = albumType
        self.fileCount = fileCount
        self.totalDuration = totalDuration
        self.totalMP3Size = totalMP3Size
        self.dateAdded = dateAdded
        self.artworkURL = artworkURL
        self.description = description
        self.tracks = tracks
    }
}

internal struct Track: Identifiable, Equatable, Codable, Sendable {
    internal let id: String
    internal let albumID: String
    internal let discNumber: Int?
    internal let number: Int
    internal let title: String
    internal let detailURL: URL
    internal let duration: TimeInterval?
    internal let mp3Size: String?

    internal init(
        id: String,
        albumID: String,
        discNumber: Int?,
        number: Int,
        title: String,
        detailURL: URL,
        duration: TimeInterval?,
        mp3Size: String?
    ) {
        self.id = id
        self.albumID = albumID
        self.discNumber = discNumber
        self.number = number
        self.title = title
        self.detailURL = detailURL
        self.duration = duration
        self.mp3Size = mp3Size
    }
}

internal struct ResolvedStream: Equatable, Sendable {
    internal let trackID: String
    internal let sourceURL: URL
    internal let sizeLabel: String?
    internal let contentLength: Int64?
    internal let etag: String?

    internal init(
        trackID: String,
        sourceURL: URL,
        sizeLabel: String?,
        contentLength: Int64?,
        etag: String?
    ) {
        self.trackID = trackID
        self.sourceURL = sourceURL
        self.sizeLabel = sizeLabel
        self.contentLength = contentLength
        self.etag = etag
    }
}

internal struct PlaybackItem: Identifiable, Equatable, Sendable {
    internal let id: String
    internal let album: AlbumDetail
    internal let track: Track

    internal init(
        id: String,
        album: AlbumDetail,
        track: Track
    ) {
        self.id = id
        self.album = album
        self.track = track
    }
}
