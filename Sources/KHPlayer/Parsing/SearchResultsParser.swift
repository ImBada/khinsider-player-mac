import Foundation
import SwiftSoup

internal enum SearchResultsParser {
    internal static func parse(html: String) throws -> [AlbumSummary] {
        let document = try SwiftSoup.parse(html, KHRequestBuilder.baseURL.absoluteString)
        let rows = try document.select("table.albumList tr")

        var albums: [AlbumSummary] = []
        albums.reserveCapacity(rows.size())

        for row in rows.array() {
            guard let albumLink = try albumLink(in: row) else {
                continue
            }

            let title = try trimmedText(from: albumLink)
            guard !title.isEmpty else {
                continue
            }

            let href = try albumLink.attr("href")
            guard let url = absoluteURL(from: href) else {
                continue
            }

            let id = url.lastPathComponent
            guard !id.isEmpty else {
                continue
            }

            let cells = try row.select("td").array()

            albums.append(
                AlbumSummary(
                    id: id,
                    title: title,
                    url: url,
                    artworkURL: try artworkURL(in: row),
                    platforms: try platforms(in: cells),
                    albumType: try albumType(in: cells),
                    year: try year(in: cells),
                    catalogNumber: nil
                )
            )
        }

        return albums
    }

    private static func albumLink(in row: Element) throws -> Element? {
        var fallback: Element?

        for link in try row.select("a[href]").array() {
            let href = try link.attr("href")
            guard href.contains("/game-soundtracks/album/") else {
                continue
            }

            if fallback == nil {
                fallback = link
            }

            if try !trimmedText(from: link).isEmpty {
                return link
            }
        }

        return fallback
    }

    private static func artworkURL(in row: Element) throws -> URL? {
        guard let image = try row.select("td.albumIcon img[src]").first() else {
            return nil
        }

        return try absoluteURL(from: image.attr("src"))
    }

    private static func platforms(in cells: [Element]) throws -> [String] {
        guard cells.indices.contains(2) else {
            return []
        }

        var platforms: [String] = []
        for link in try cells[2].select("a").array() {
            let text = try trimmedText(from: link)
            if !text.isEmpty {
                platforms.append(text)
            }
        }

        return platforms
    }

    private static func albumType(in cells: [Element]) throws -> String? {
        guard cells.indices.contains(3) else {
            return nil
        }

        return try nilIfBlank(trimmedText(from: cells[3]))
    }

    private static func year(in cells: [Element]) throws -> Int? {
        guard cells.indices.contains(4) else {
            return nil
        }

        guard let yearText = try nilIfBlank(trimmedText(from: cells[4])) else {
            return nil
        }

        return Int(yearText)
    }

    private static func trimmedText(from element: Element) throws -> String {
        try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nilIfBlank(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private static func absoluteURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmedValue), url.scheme != nil {
            return url
        }

        return URL(string: trimmedValue, relativeTo: KHRequestBuilder.baseURL)?.absoluteURL
    }
}
