import Foundation
import SwiftSoup

internal enum HomeSectionParser {
    internal static func parse(
        html: String,
        source: HomeSectionSource,
        limit: Int = 20
    ) throws -> [AlbumSummary] {
        let document = try SwiftSoup.parse(html, HomeSectionSource.latestSoundtracks.url.absoluteString)
        let rows = try albumRows(in: document, source: source)

        var albums: [AlbumSummary] = []
        albums.reserveCapacity(min(limit, rows.count))

        for row in rows {
            guard albums.count < limit else {
                break
            }

            guard let album = try albumSummary(in: row) else {
                continue
            }

            albums.append(album)
        }

        return albums
    }

    internal static func parseReaderMarkdown(_ markdown: String, limit: Int = 20) -> [AlbumSummary] {
        var albums: [AlbumSummary] = []
        albums.reserveCapacity(limit)

        for line in markdown.components(separatedBy: .newlines) {
            guard albums.count < limit else {
                break
            }

            let artworkURL = firstMatch(
                in: line,
                pattern: #"!\[[^\]]*\]\(([^)]+)\)"#,
                captureIndex: 1
            ).flatMap(URL.init(string:))
            let lineWithoutImages = line.replacingOccurrences(
                of: #"!\[[^\]]*\]\([^)]+\)"#,
                with: "",
                options: .regularExpression
            )

            guard let match = firstAlbumLink(in: lineWithoutImages),
                  let url = URL(string: match.urlString) else {
                continue
            }

            let cleaned = cleanedTitleAndYear(from: match.title)
            let id = url.lastPathComponent
            guard !id.isEmpty, !cleaned.title.isEmpty else {
                continue
            }

            albums.append(
                AlbumSummary(
                    id: id,
                    title: cleaned.title,
                    url: url,
                    artworkURL: artworkURL,
                    platforms: [],
                    albumType: albumType(from: match.title),
                    year: cleaned.year,
                    catalogNumber: nil
                )
            )
        }

        return albums
    }

    private static func albumRows(in document: Document, source: HomeSectionSource) throws -> [Element] {
        let selector: String

        switch source {
        case .latestSoundtracks:
            selector = "#homepageLatestSoundtracks table.albumList tr"
        case .top40, .mostFavorites, .top100NewlyAdded:
            selector = "table.albumList tr"
        }

        return try document.select(selector).array()
    }

    private static func albumSummary(in row: Element) throws -> AlbumSummary? {
        guard let albumLink = try albumLink(in: row) else {
            return nil
        }

        let title = try trimmedText(from: albumLink)
        guard !title.isEmpty else {
            return nil
        }

        let href = try albumLink.attr("href")
        guard let url = absoluteURL(from: href) else {
            return nil
        }

        let id = url.lastPathComponent
        guard !id.isEmpty else {
            return nil
        }

        let cells = try row.select("td").array()

        return AlbumSummary(
            id: id,
            title: title,
            url: url,
            artworkURL: try artworkURL(in: row),
            platforms: try platforms(in: cells),
            albumType: try albumType(in: cells),
            year: try year(in: cells),
            catalogNumber: nil
        )
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

        return absoluteURL(from: try image.attr("src"))
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

        return URL(string: trimmedValue, relativeTo: HomeSectionSource.latestSoundtracks.url)?.absoluteURL
    }

    private static func firstAlbumLink(in line: String) -> (title: String, urlString: String)? {
        let pattern = #"\[([^\]]+)\]\((https://downloads\.khinsider\.com/game-soundtracks/album/[^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let titleRange = Range(match.range(at: 1), in: line),
              let urlRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        return (
            String(line[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines),
            String(line[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func firstMatch(
        in line: String,
        pattern: String,
        captureIndex: Int
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > captureIndex,
              let captureRange = Range(match.range(at: captureIndex), in: line) else {
            return nil
        }

        return String(line[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedTitleAndYear(from rawTitle: String) -> (title: String, year: Int?) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"\s*\((\d{4})\)\s*$"#) else {
            return (title, nil)
        }

        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              let yearRange = Range(match.range(at: 1), in: title),
              let fullRange = Range(match.range(at: 0), in: title) else {
            return (title, nil)
        }

        let year = Int(title[yearRange])
        let cleanedTitle = title.replacingCharacters(in: fullRange, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanedTitle, year)
    }

    private static func albumType(from rawTitle: String) -> String? {
        let lowercased = rawTitle.lowercased()
        if lowercased.contains("(gamerip)") {
            return "Gamerip"
        }
        if lowercased.contains("(arrangement)") {
            return "Arrangement"
        }
        if lowercased.contains("(remix)") {
            return "Remix"
        }
        return nil
    }
}
