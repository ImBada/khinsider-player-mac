import Foundation
import SwiftSoup

internal enum TrackDetailParser {
    internal static func parse(html: String, trackID: String) throws -> [ResolvedStream] {
        let document = try SwiftSoup.parse(html)
        let links = try document.select("a[href]").array()

        var streams: [ResolvedStream] = []
        var seenURLs = Set<String>()
        streams.reserveCapacity(links.count)

        for link in links {
            let href = try link.attr("href")
            guard let url = absoluteTreasureChestURL(from: href),
                  isMP3URL(url) else {
                continue
            }

            guard seenURLs.insert(url.absoluteString).inserted else {
                continue
            }

            streams.append(
                ResolvedStream(
                    trackID: trackID,
                    sourceURL: url,
                    sizeLabel: try sizeLabel(fromParentParagraphOf: link),
                    contentLength: nil,
                    etag: nil
                )
            )
        }

        return streams
    }
}

private extension TrackDetailParser {
    static func absoluteTreasureChestURL(from value: String) -> URL? {
        let trimmedValue = trim(value)
        guard var components = URLComponents(string: trimmedValue),
              components.scheme != nil,
              let host = components.host,
              isTreasureChestHost(host) else {
            return nil
        }

        components.percentEncodedPath = percentEncodePreservingEscapes(
            components.path,
            allowedCharacters: .urlPathAllowed
        )
        components.percentEncodedQuery = components.query.map {
            percentEncodePreservingEscapes($0, allowedCharacters: .urlQueryAllowed)
        }
        components.percentEncodedFragment = components.fragment.map {
            percentEncodePreservingEscapes($0, allowedCharacters: .urlFragmentAllowed)
        }
        return components.url
    }

    static func isTreasureChestHost(_ host: String) -> Bool {
        let normalizedHost = host.lowercased()
        return normalizedHost == "vgmtreasurechest.com"
            || normalizedHost.hasSuffix(".vgmtreasurechest.com")
    }

    static func isMP3URL(_ url: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare("mp3") == .orderedSame
    }

    static func sizeLabel(fromParentParagraphOf link: Element) throws -> String? {
        guard let paragraph = parentParagraph(containing: link) else {
            return nil
        }

        return firstParenthesizedValue(in: try paragraph.text())
    }

    static func parentParagraph(containing element: Element) -> Element? {
        if element.tagName().caseInsensitiveCompare("p") == .orderedSame {
            return element
        }

        return element.parents().array().first { parent in
            parent.tagName().caseInsensitiveCompare("p") == .orderedSame
        }
    }

    static func firstParenthesizedValue(in value: String) -> String? {
        guard let open = value.firstIndex(of: "(") else {
            return nil
        }

        let searchStart = value.index(after: open)
        guard let close = value[searchStart...].firstIndex(of: ")") else {
            return nil
        }

        return nilIfBlank(String(value[searchStart..<close]))
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

    static func percentEncodePreservingEscapes(
        _ value: String,
        allowedCharacters: CharacterSet
    ) -> String {
        var allowedCharacters = allowedCharacters
        allowedCharacters.remove(charactersIn: "%")

        var encodedValue = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "%",
               let firstHexIndex = value.index(index, offsetBy: 1, limitedBy: value.endIndex),
               firstHexIndex < value.endIndex,
               let secondHexIndex = value.index(index, offsetBy: 2, limitedBy: value.endIndex),
               secondHexIndex < value.endIndex,
               isHexDigit(value[firstHexIndex]),
               isHexDigit(value[secondHexIndex]) {
                encodedValue.append("%")
                encodedValue.append(value[firstHexIndex])
                encodedValue.append(value[secondHexIndex])
                index = value.index(after: secondHexIndex)
                continue
            }

            let character = String(value[index])
            encodedValue += character.addingPercentEncoding(
                withAllowedCharacters: allowedCharacters
            ) ?? character
            index = value.index(after: index)
        }

        return encodedValue
    }

    static func isHexDigit(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }

        return CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(scalar)
    }
}
