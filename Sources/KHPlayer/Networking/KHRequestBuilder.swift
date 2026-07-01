import Foundation

internal enum SearchType: String, Sendable {
    case album
    case song
}

internal enum SearchSort: String, Sendable {
    case name
    case timestamp
    case popularity
    case year
    case relevance
}

internal enum KHRequestBuilder {
    internal static let baseURL = URL(string: "https://downloads.khinsider.com")!

    internal static func searchURL(query: String, type: SearchType, sort: SearchSort) throws -> URL {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw KHError.invalidURL("empty search query")
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "search", value: trimmedQuery),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "sort", value: sort.rawValue)
        ]

        guard let url = components?.url else {
            throw KHError.invalidURL("search query")
        }

        return url
    }
}
