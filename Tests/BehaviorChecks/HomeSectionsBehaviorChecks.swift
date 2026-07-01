import Foundation

@main
struct HomeSectionsBehaviorChecks {
    static func main() throws {
        try checkLatestSoundtracksParserLimitsToFirstTwentyAlbums()
        try checkReaderMarkdownParserLimitsToFirstTwentyAlbums()
        try checkHomeSectionsCacheUsesTwentyFourHourFreshnessWindow()
        try checkHomeSectionsCacheRejectsPartialSnapshots()
    }

    private static func checkLatestSoundtracksParserLimitsToFirstTwentyAlbums() throws {
        let html = """
        <html>
        <body>
            <div id="homepageLatestSoundtracks">
                <h2>Latest Soundtracks</h2>
                <table class="albumList">
                    <tr><th></th><th>Album</th><th>Platform</th><th>Type</th><th>Year</th></tr>
                    \(albumRows(count: 24))
                </table>
            </div>
            <table class="albumList">
                <tr><td class="albumIcon"><a href="/game-soundtracks/album/ignore-me"><img src="https://example.com/ignore.jpg"></a></td><td><a href="/game-soundtracks/album/ignore-me">Ignore Me</a></td><td></td><td>Soundtrack</td><td>2026</td></tr>
            </table>
        </body>
        </html>
        """

        let albums = try HomeSectionParser.parse(
            html: html,
            source: .latestSoundtracks,
            limit: 20
        )

        precondition(albums.count == 20)
        precondition(albums[0].id == "album-1")
        precondition(albums[0].title == "Album 1")
        precondition(albums[0].platforms == ["Switch", "Windows"])
        precondition(albums[0].albumType == "Soundtrack")
        precondition(albums[0].year == 2026)
        precondition(albums[19].id == "album-20")
    }

    private static func checkHomeSectionsCacheUsesTwentyFourHourFreshnessWindow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let cache = HomeSectionsCache(
            directory: directory,
            freshnessInterval: 24 * 60 * 60
        )
        let snapshot = HomeSectionsSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            sections: completeSections()
        )

        try cache.save(snapshot)

        let fresh = try cache.load(now: Date(timeIntervalSince1970: 1_000 + 60))
        precondition(fresh?.sections.count == HomeSectionSource.allCases.count)
        precondition(fresh?.sections.first?.albums.first?.id == "latestSoundtracks-album")

        let stale = try cache.load(now: Date(timeIntervalSince1970: 1_000 + (24 * 60 * 60) + 1))
        precondition(stale == nil)
    }

    private static func checkReaderMarkdownParserLimitsToFirstTwentyAlbums() throws {
        let markdown = (1...24).map { index in
            """
            | [![Image \(index)](https://example.com/album-\(index).jpg)](https://downloads.khinsider.com/game-soundtracks/album/album-\(index)) | \(index). | [Album \(index) (2026)](https://downloads.khinsider.com/game-soundtracks/album/album-\(index)) |
            """
        }.joined(separator: "\n")

        let albums = HomeSectionParser.parseReaderMarkdown(markdown, limit: 20)

        precondition(albums.count == 20)
        precondition(albums[0].id == "album-1")
        precondition(albums[0].title == "Album 1")
        precondition(albums[0].year == 2026)
        precondition(albums[0].artworkURL?.absoluteString == "https://example.com/album-1.jpg")
        precondition(albums[19].id == "album-20")
    }

    private static func checkHomeSectionsCacheRejectsPartialSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let cache = HomeSectionsCache(
            directory: directory,
            freshnessInterval: 24 * 60 * 60
        )
        let snapshot = HomeSectionsSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            sections: [
                HomeSection(
                    source: .latestSoundtracks,
                    albums: [sampleAlbum(id: "latest")]
                )
            ]
        )

        try cache.save(snapshot)

        let loaded = try cache.load(now: Date(timeIntervalSince1970: 1_000 + 60))
        precondition(loaded == nil)
    }

    private static func albumRows(count: Int) -> String {
        (1...count).map { index in
            """
            <tr>
                <td class="albumIcon">
                    <a href="/game-soundtracks/album/album-\(index)">
                        <img src="https://example.com/album-\(index).jpg">
                    </a>
                </td>
                <td><a href="/game-soundtracks/album/album-\(index)">Album \(index)</a></td>
                <td><a href="/game-soundtracks/nintendo-switch">Switch</a>, <a href="/game-soundtracks/windows">Windows</a></td>
                <td>Soundtrack</td>
                <td>2026</td>
            </tr>
            """
        }.joined(separator: "\n")
    }

    private static func sampleAlbum(id: String) -> AlbumSummary {
        AlbumSummary(
            id: id,
            title: id,
            url: URL(string: "https://downloads.khinsider.com/game-soundtracks/album/\(id)")!,
            artworkURL: nil,
            platforms: [],
            albumType: nil,
            year: nil,
            catalogNumber: nil
        )
    }

    private static func completeSections() -> [HomeSection] {
        HomeSectionSource.allCases.map { source in
            HomeSection(
                source: source,
                albums: [sampleAlbum(id: "\(source.rawValue)-album")]
            )
        }
    }
}
