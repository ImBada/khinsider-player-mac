import Foundation
import SwiftSoup

internal enum AlbumPageParser {
    internal static func parse(html: String, url: URL) throws -> AlbumDetail {
        let document = try SwiftSoup.parse(html, url.absoluteString)
        let albumID = url.lastPathComponent

        guard let titleElement = try document.select("h2").first() else {
            throw KHError.parserMissingElement("album title")
        }

        let title = try trimmedText(from: titleElement)
        guard !title.isEmpty else {
            throw KHError.parserMissingElement("album title")
        }

        let metadataParagraph = try metadataParagraph(in: document)
        let parsedMetadataLines = try metadataParagraph.map {
            try Self.metadataLines(in: $0, baseURL: url)
        } ?? []
        return AlbumDetail(
            id: albumID,
            title: title,
            url: url,
            alternativeTitles: try alternativeTitles(in: document, baseURL: url),
            platforms: try platforms(in: parsedMetadataLines, baseURL: url),
            year: intValue(label: "Year", in: parsedMetadataLines),
            publisher: metadataValue(label: "Published by", in: parsedMetadataLines),
            albumType: metadataValue(label: "Album type", in: parsedMetadataLines),
            fileCount: intValue(label: "Number of Files", in: parsedMetadataLines),
            totalDuration: try totalDuration(in: document),
            totalMP3Size: totalMP3Size(in: parsedMetadataLines),
            dateAdded: metadataValue(label: "Date Added", in: parsedMetadataLines),
            artworkURL: try artworkURL(in: document, baseURL: url),
            description: try description(in: document),
            tracks: try tracks(in: document, albumID: albumID, baseURL: url)
        )
    }
}

private extension AlbumPageParser {
    struct MetadataLine {
        let html: String
        let text: String
    }

    static func metadataParagraph(in document: Document) throws -> Element? {
        for paragraph in try document.select("p").array() {
            guard !paragraph.hasClass("albuminfoAlternativeTitles") else {
                continue
            }

            let text = try trimmedText(from: paragraph)
            if text.localizedCaseInsensitiveContains("Platforms:")
                || text.localizedCaseInsensitiveContains("Number of Files:")
                || text.localizedCaseInsensitiveContains("Total Filesize:") {
                return paragraph
            }
        }

        return nil
    }

    static func metadataLines(in paragraph: Element, baseURL: URL) throws -> [MetadataLine] {
        try splitHTMLOnBreaks(try paragraph.html()).compactMap { fragment in
            let text = try text(fromHTMLFragment: fragment, baseURL: baseURL)
            guard !text.isEmpty else {
                return nil
            }

            return MetadataLine(html: fragment, text: text)
        }
    }

    static func alternativeTitles(in document: Document, baseURL: URL) throws -> [String] {
        guard let element = try document.select(".albuminfoAlternativeTitles").first() else {
            return []
        }

        return try splitHTMLOnBreaks(try element.html()).compactMap { fragment in
            nilIfBlank(try text(fromHTMLFragment: fragment, baseURL: baseURL))
        }
    }

    static func platforms(in lines: [MetadataLine], baseURL: URL) throws -> [String] {
        guard let line = line(label: "Platforms", in: lines) else {
            return []
        }

        let fragmentDocument = try SwiftSoup.parseBodyFragment(line.html, baseURL.absoluteString)
        return try fragmentDocument.select("a[href]").array().compactMap { link in
            nilIfBlank(try trimmedText(from: link))
        }
    }

    static func totalMP3Size(in lines: [MetadataLine]) -> String? {
        guard let value = metadataValue(label: "Total Filesize", in: lines) else {
            return nil
        }

        for match in capturedMatches(
            in: value,
            pattern: #"([0-9]+(?:\.[0-9]+)?\s*(?:B|KB|MB|GB|TB))\s*\((MP3)\)"#
        ) {
            guard match.count == 2 else {
                continue
            }

            if match[1].caseInsensitiveCompare("MP3") == .orderedSame {
                return match[0]
            }
        }

        return nil
    }

    static func artworkURL(in document: Document, baseURL: URL) throws -> URL? {
        guard let link = try document.select(".albumImage a[href]").first() else {
            return nil
        }

        return try absoluteURL(from: link.attr("href"), baseURL: baseURL)
    }

    static func description(in document: Document) throws -> String? {
        for heading in try document.select("h2").array() {
            guard try trimmedText(from: heading).caseInsensitiveCompare("Description") == .orderedSame else {
                continue
            }

            guard let paragraph = try heading.nextElementSibling(),
                  paragraph.tagName().caseInsensitiveCompare("p") == .orderedSame else {
                return nil
            }

            return try nilIfBlank(trimmedText(from: paragraph))
        }

        return nil
    }

    static func tracks(in document: Document, albumID: String, baseURL: URL) throws -> [Track] {
        let rows = try document.select("table#songlist tr")
        var tracks: [Track] = []
        tracks.reserveCapacity(rows.size())

        for row in rows.array() {
            guard try !shouldSkipTrackRow(row) else {
                continue
            }

            if let track = try track(
                in: row,
                albumID: albumID,
                baseURL: baseURL,
                fallbackIndex: tracks.count
            ) {
                tracks.append(track)
            }
        }

        return tracks
    }

    static func shouldSkipTrackRow(_ row: Element) throws -> Bool {
        let rowID = try row.attr("id").lowercased()
        if rowID.contains("header") || rowID.contains("footer") {
            return true
        }

        return try !row.select("th").array().isEmpty
    }

    static func track(
        in row: Element,
        albumID: String,
        baseURL: URL,
        fallbackIndex: Int
    ) throws -> Track? {
        let cells = try row.select("td").array()
        guard let titleInfo = try titleInfo(in: cells),
              let detailURL = try absoluteURL(from: titleInfo.href, baseURL: baseURL) else {
            return nil
        }
        let number = try trackNumberBeforeTitle(in: cells, titleIndex: titleInfo.index) ?? fallbackIndex + 1
        let discNumber = try discNumberBeforeTitle(in: cells, titleIndex: titleInfo.index)

        let cellsAfterTitle = cells.dropFirst(titleInfo.index + 1)
        let trackDuration = try cellsAfterTitle.lazy.compactMap { cell in
            try Self.duration(from: trimmedText(from: cell))
        }.first
        let sizes = try cellsAfterTitle.compactMap { cell in
            try sizeLabel(from: trimmedText(from: cell))
        }

        return Track(
            id: trackID(albumID: albumID, detailURL: detailURL, fallbackIndex: fallbackIndex),
            albumID: albumID,
            discNumber: discNumber,
            number: number,
            title: titleInfo.title,
            detailURL: detailURL,
            duration: trackDuration,
            mp3Size: sizes.first
        )
    }

    static func titleInfo(in cells: [Element]) throws -> (index: Int, title: String, href: String)? {
        for index in cells.indices {
            guard let link = try cells[index].select("a[href]").first() else {
                continue
            }

            let title = try trimmedText(from: link)
            guard !title.isEmpty,
                  duration(from: title) == nil,
                  sizeLabel(from: title) == nil else {
                continue
            }

            return (index, title, try link.attr("href"))
        }

        return nil
    }

    static func trackNumberBeforeTitle(in cells: [Element], titleIndex: Int) throws -> Int? {
        guard titleIndex > cells.startIndex else {
            return nil
        }

        for index in stride(from: titleIndex - 1, through: cells.startIndex, by: -1) {
            if let number = try trackNumber(from: cells[index]) {
                return number
            }
        }

        return nil
    }

    static func discNumberBeforeTitle(in cells: [Element], titleIndex: Int) throws -> Int? {
        guard titleIndex > cells.startIndex else {
            return nil
        }

        let numericValues = try cells[cells.startIndex..<titleIndex].compactMap { cell in
            try trackNumber(from: cell)
        }

        guard numericValues.count >= 2 else {
            return nil
        }

        return numericValues[numericValues.count - 2]
    }

    static func trackID(albumID: String, detailURL: URL, fallbackIndex: Int) -> String {
        let component = decodePercentEncoding(detailURL.lastPathComponent)
        let normalizedComponent = component.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]+"#,
            with: "-",
            options: [.regularExpression]
        )
        .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))

        let suffix = normalizedComponent.isEmpty ? "track" : normalizedComponent
        return "\(albumID)-\(fallbackIndex + 1)-\(suffix)"
    }

    static func decodePercentEncoding(_ value: String) -> String {
        var result = value
        for _ in 0..<2 {
            guard let decoded = result.removingPercentEncoding,
                  decoded != result else {
                break
            }

            result = decoded
        }

        return result
    }

    static func totalDuration(in document: Document) throws -> TimeInterval? {
        guard let footer = try document.select("table#songlist tr#songlist_footer").first() else {
            return nil
        }

        for cell in footer.children().array() {
            if let duration = try duration(from: trimmedText(from: cell)) {
                return duration
            }
        }

        return nil
    }

    static func trackNumber(from cell: Element) throws -> Int? {
        guard let value = firstCapture(
            in: try trimmedText(from: cell),
            pattern: #"^\s*(\d+)\.?\s*$"#
        ) else {
            return nil
        }

        return Int(value)
    }

    static func intValue(label: String, in lines: [MetadataLine]) -> Int? {
        guard let value = metadataValue(label: label, in: lines),
              let integer = firstCapture(in: value, pattern: #"(\d+)"#) else {
            return nil
        }

        return Int(integer)
    }

    static func metadataValue(label: String, in lines: [MetadataLine]) -> String? {
        guard let line = line(label: label, in: lines) else {
            return nil
        }

        let prefix = "\(label):"
        guard let range = line.text.range(of: prefix, options: [.caseInsensitive, .anchored]) else {
            return nil
        }

        return nilIfBlank(String(line.text[range.upperBound...]))
    }

    static func line(label: String, in lines: [MetadataLine]) -> MetadataLine? {
        let prefix = "\(label):"
        return lines.first { line in
            line.text.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    static func duration(from text: String) -> TimeInterval? {
        let value = trim(text).lowercased()
        guard !value.isEmpty else {
            return nil
        }

        let colonParts = value.split(separator: ":")
        if colonParts.count == 2 || colonParts.count == 3 {
            let numbers = colonParts.compactMap { Int($0) }
            guard numbers.count == colonParts.count else {
                return nil
            }

            if numbers.count == 2 {
                return TimeInterval(numbers[0] * 60 + numbers[1])
            }

            return TimeInterval(numbers[0] * 3_600 + numbers[1] * 60 + numbers[2])
        }

        guard let match = capturedMatches(
            in: value,
            pattern: #"^\s*(?:(\d+)\s*h(?:ours?)?)?\s*(?:(\d+)\s*m(?:in(?:ute)?s?)?)?\s*(?:(\d+)\s*s(?:ec(?:ond)?s?)?)?\s*$"#
        ).first else {
            return nil
        }

        let hours = match[safe: 0].flatMap(Int.init)
        let minutes = match[safe: 1].flatMap(Int.init)
        let seconds = match[safe: 2].flatMap(Int.init)
        guard hours != nil || minutes != nil || seconds != nil else {
            return nil
        }

        return TimeInterval((hours ?? 0) * 3_600 + (minutes ?? 0) * 60 + (seconds ?? 0))
    }

    static func sizeLabel(from text: String) -> String? {
        firstCapture(
            in: text,
            pattern: #"\b([0-9]+(?:\.[0-9]+)?\s*(?:B|KB|MB|GB|TB))\b"#
        )
    }

    static func text(fromHTMLFragment html: String, baseURL: URL) throws -> String {
        let document = try SwiftSoup.parseBodyFragment(html, baseURL.absoluteString)
        return try trimmedText(from: document)
    }

    static func trimmedText(from element: Element) throws -> String {
        try trim(element.text())
    }

    static func splitHTMLOnBreaks(_ html: String) -> [String] {
        html.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: "\n",
            options: [.caseInsensitive, .regularExpression]
        )
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    }

    static func nilIfBlank(_ value: String) -> String? {
        let trimmedValue = trim(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func trim(_ value: String) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{00a0}"))
        )
    }

    static func absoluteURL(from value: String, baseURL: URL) throws -> URL? {
        let trimmedValue = trim(value)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if trimmedValue.hasPrefix("//") {
            return URL(string: "https:\(trimmedValue)")
        }

        if let url = URL(string: trimmedValue), url.scheme != nil {
            return url
        }

        let directoryURL = baseURL.absoluteString.hasSuffix("/")
            ? baseURL
            : URL(string: "\(baseURL.absoluteString)/") ?? baseURL
        return URL(string: trimmedValue, relativeTo: directoryURL)?.absoluteURL
    }

    static func firstCapture(in value: String, pattern: String) -> String? {
        capturedMatches(in: value, pattern: pattern).first?.first
    }

    static func capturedMatches(in value: String, pattern: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).map { match in
            (1..<match.numberOfRanges).map { index in
                guard match.range(at: index).location != NSNotFound,
                      let range = Range(match.range(at: index), in: value) else {
                    return ""
                }

                return String(value[range])
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
