import Foundation

internal enum HomeSectionSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case latestSoundtracks
    case top40
    case mostFavorites
    case top100NewlyAdded

    internal var id: String {
        rawValue
    }

    internal var title: String {
        switch self {
        case .latestSoundtracks:
            "Latest Soundtracks"
        case .top40:
            "Top 40"
        case .mostFavorites:
            "Most Favorites"
        case .top100NewlyAdded:
            "Top 100 Newly Added Soundtracks"
        }
    }

    internal var url: URL {
        switch self {
        case .latestSoundtracks:
            URL(string: "https://downloads.khinsider.com/")!
        case .top40:
            URL(string: "https://downloads.khinsider.com/top40")!
        case .mostFavorites:
            URL(string: "https://downloads.khinsider.com/most-favorites")!
        case .top100NewlyAdded:
            URL(string: "https://downloads.khinsider.com/top-100-newly-added")!
        }
    }

    internal var readerURL: URL {
        URL(string: "https://r.jina.ai/http://\(url.absoluteString)")!
    }
}

internal struct HomeSection: Equatable, Codable, Sendable, Identifiable {
    internal let source: HomeSectionSource
    internal let albums: [AlbumSummary]

    internal var id: HomeSectionSource {
        source
    }

    internal init(source: HomeSectionSource, albums: [AlbumSummary]) {
        self.source = source
        self.albums = albums
    }
}

internal struct HomeSectionsSnapshot: Equatable, Codable, Sendable {
    internal let fetchedAt: Date
    internal let sections: [HomeSection]

    internal init(fetchedAt: Date, sections: [HomeSection]) {
        self.fetchedAt = fetchedAt
        self.sections = sections
    }
}
