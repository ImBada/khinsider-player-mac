# KHInsider Streaming Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS player for downloads.khinsider.com that searches and browses albums, streams tracks, and stores only local user data plus a bounded cache for the currently playing song.

**Architecture:** The app is a SwiftPM-based macOS SwiftUI application with a native shell, HTML parsing adapters for KHInsider pages, an `AVPlayer` playback engine, and a custom `AVAssetResourceLoaderDelegate` that enforces a one-track bounded disk cache. Site account features are not used; favorites, history, and playlists are local SQLite data.

**Tech Stack:** Swift 6.4, SwiftUI, AVFoundation, MediaPlayer, URLSession, SwiftSoup 2.9.6, GRDB 7.11.1, XCTest, SQLite.

---

## Product Boundary

This app is a streaming player, not a downloader.

- It does not log in to KHInsider.
- It does not integrate KHInsider "My Music", server favorites, server history, uploads, requests, or playlists.
- It does not call `/cp/favorites`, `/cp/history`, `/cp/add_album`, or `/playlist` endpoints.
- It does not prefetch whole albums.
- It resolves only the selected track's playable URL at playback time.
- It caches only the currently playing audio stream under a fixed byte limit.
- It stores user favorites, history, local playlists, and playback preferences locally.

## Site Findings To Preserve

Reference pages:

- Home: `https://downloads.khinsider.com/`
- Search: `https://downloads.khinsider.com/search?search=persona`
- Album example: `https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022`
- Track detail example: `https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022/01.%2520Persona.mp3`
- Robots: `https://downloads.khinsider.com/robots.txt`

Observed behavior:

- Home search submits `GET /search` with query parameter `search`.
- Search result pages use an HTML table with album rows. `type=album` and `type=song` both return album-oriented results.
- Album pages expose album metadata, artwork, track rows, duration, MP3 size, FLAC size, and per-track detail links.
- Track rows link to KHInsider detail pages; the real media URLs are on the detail pages.
- Track detail pages expose MP3 and, when available, FLAC links on `*.vgmtreasurechest.com`.
- The media server supports byte ranges, which is required for seeking and streaming.
- Broad scraping-like requests can be blocked by Cloudflare; requests must be user-driven and rate limited.

## Cache Policy

The audio cache is active-track-only.

- Directory: `~/Library/Caches/com.bada.khinsider-player-mac/ActiveTrackCache`
- Default limit: 256 MB
- User-selectable limits: 64 MB, 128 MB, 256 MB, 512 MB
- The app deletes stale active-track cache files on launch.
- Starting a new track clears the previous active track cache.
- A cache entry is keyed by resolved media URL plus content length and ETag when available.
- The cache stores fixed-size chunks so seeks can reuse already fetched data without keeping the entire file.
- Chunk size: 512 KiB.
- When the cache reaches the selected byte limit, least-recently-used chunks for the current track are removed.
- If a file is larger than the limit, playback continues by streaming uncached ranges from the network.
- Artwork and parsed metadata use separate small caches and are not treated as offline music storage.

## User Experience

The first screen is the usable player, not a landing page.

- Left sidebar: Search, Browse, Top/New, Favorites, History, Playlists, Settings.
- Main area: search results, browse lists, album detail, or local library views.
- Album detail: artwork, title, alternative titles, platform/year/type/publisher, total duration, track table, play button, favorite button.
- Track table: number, title, duration, MP3 size, FLAC size when present, local playlist action.
- Bottom mini-player: artwork, track title, album title, previous/play-next, progress, volume, shuffle, repeat.
- Settings: cache size, preferred stream format, clear cache, clear history.
- Preferred format defaults to MP3. FLAC is opt-in because it increases bandwidth and cache pressure.

## File Structure

Create this structure:

```text
Package.swift
README.md
Sources/KHPlayer/App/KHPlayerApp.swift
Sources/KHPlayer/App/AppState.swift
Sources/KHPlayer/App/EnvironmentValues.swift
Sources/KHPlayer/Domain/Models.swift
Sources/KHPlayer/Domain/KHError.swift
Sources/KHPlayer/Networking/KHClient.swift
Sources/KHPlayer/Networking/KHRequestBuilder.swift
Sources/KHPlayer/Parsing/SearchResultsParser.swift
Sources/KHPlayer/Parsing/AlbumPageParser.swift
Sources/KHPlayer/Parsing/TrackDetailParser.swift
Sources/KHPlayer/Playback/PlaybackEngine.swift
Sources/KHPlayer/Playback/PlaybackQueue.swift
Sources/KHPlayer/Playback/StreamResolver.swift
Sources/KHPlayer/Playback/ActiveTrackCache.swift
Sources/KHPlayer/Playback/CachingStreamResourceLoader.swift
Sources/KHPlayer/Playback/NowPlayingBridge.swift
Sources/KHPlayer/Persistence/LibraryStore.swift
Sources/KHPlayer/Persistence/SchemaMigrator.swift
Sources/KHPlayer/Persistence/Records.swift
Sources/KHPlayer/Features/Shell/ContentView.swift
Sources/KHPlayer/Features/Shell/SidebarView.swift
Sources/KHPlayer/Features/Search/SearchView.swift
Sources/KHPlayer/Features/Search/SearchViewModel.swift
Sources/KHPlayer/Features/Album/AlbumDetailView.swift
Sources/KHPlayer/Features/Album/AlbumDetailViewModel.swift
Sources/KHPlayer/Features/Player/MiniPlayerView.swift
Sources/KHPlayer/Features/Library/LocalLibraryViews.swift
Sources/KHPlayer/Features/Settings/SettingsView.swift
Sources/KHPlayer/Resources/AppAssets.xcassets
Tests/KHPlayerTests/Fixtures/SearchPersonaAlbums.html
Tests/KHPlayerTests/Fixtures/PersonaVinylAlbum.html
Tests/KHPlayerTests/Fixtures/PersonaTrackDetail.html
Tests/KHPlayerTests/KHRequestBuilderTests.swift
Tests/KHPlayerTests/SearchResultsParserTests.swift
Tests/KHPlayerTests/AlbumPageParserTests.swift
Tests/KHPlayerTests/TrackDetailParserTests.swift
Tests/KHPlayerTests/ActiveTrackCacheTests.swift
Tests/KHPlayerTests/LibraryStoreTests.swift
Tests/KHPlayerTests/PlaybackQueueTests.swift
```

## Data Types

Define these domain types in `Sources/KHPlayer/Domain/Models.swift`:

```swift
import Foundation

struct AlbumSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let url: URL
    let artworkURL: URL?
    let platforms: [String]
    let albumType: String?
    let year: Int?
    let catalogNumber: String?
}

struct AlbumDetail: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let url: URL
    let alternativeTitles: [String]
    let platforms: [String]
    let year: Int?
    let publisher: String?
    let albumType: String?
    let fileCount: Int?
    let totalDuration: TimeInterval?
    let totalMP3Size: String?
    let totalFLACSize: String?
    let dateAdded: String?
    let artworkURL: URL?
    let description: String?
    let tracks: [Track]
}

struct Track: Identifiable, Equatable, Sendable {
    let id: String
    let albumID: String
    let number: Int
    let title: String
    let detailURL: URL
    let duration: TimeInterval?
    let mp3Size: String?
    let flacSize: String?
}

struct ResolvedStream: Equatable, Sendable {
    enum Format: String, CaseIterable, Sendable {
        case mp3
        case flac
    }

    let trackID: String
    let sourceURL: URL
    let format: Format
    let sizeLabel: String?
    let contentLength: Int64?
    let etag: String?
}

struct PlaybackItem: Identifiable, Equatable, Sendable {
    let id: String
    let album: AlbumDetail
    let track: Track
    let preferredFormat: ResolvedStream.Format
}
```

Define these errors in `Sources/KHPlayer/Domain/KHError.swift`:

```swift
import Foundation

enum KHError: LocalizedError, Equatable {
    case invalidURL(String)
    case blockedByCloudflare
    case networkStatus(Int)
    case parserMissingElement(String)
    case streamNotFound(trackTitle: String)
    case cacheLimitTooSmall
    case persistence(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .blockedByCloudflare:
            return "KHInsider blocked the request. Try again later."
        case .networkStatus(let status):
            return "Network request failed with status \(status)."
        case .parserMissingElement(let name):
            return "The page is missing expected content: \(name)."
        case .streamNotFound(let trackTitle):
            return "No playable stream found for \(trackTitle)."
        case .cacheLimitTooSmall:
            return "The selected cache limit is too small for streaming."
        case .persistence(let message):
            return "Local library error: \(message)"
        }
    }
}
```

## Implementation Tasks

### Task 1: Bootstrap SwiftPM macOS App

**Files:**
- Create: `Package.swift`
- Create: `Sources/KHPlayer/App/KHPlayerApp.swift`
- Create: `Sources/KHPlayer/Features/Shell/ContentView.swift`
- Create: `README.md`

- [ ] **Step 1: Create package manifest**

Create `Package.swift` with:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KHInsiderPlayerMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KHPlayer", targets: ["KHPlayer"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.9.6"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1")
    ],
    targets: [
        .executableTarget(
            name: "KHPlayer",
            dependencies: [
                "SwiftSoup",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/KHPlayer",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KHPlayerTests",
            dependencies: ["KHPlayer"],
            path: "Tests/KHPlayerTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
```

- [ ] **Step 2: Add minimal app entry point**

Create `Sources/KHPlayer/App/KHPlayerApp.swift`:

```swift
import SwiftUI

@main
struct KHPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}
```

- [ ] **Step 3: Add minimal content view**

Create `Sources/KHPlayer/Features/Shell/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Search")
        } detail: {
            Text("KHInsider Player")
        }
    }
}
```

- [ ] **Step 4: Add README project boundary**

Create `README.md`:

```markdown
# KHInsider Player for macOS

Native macOS streaming player for downloads.khinsider.com.

The app streams individual tracks on demand. It does not log in to KHInsider, does not integrate KHInsider account data, and does not download full albums. Favorites, history, and playlists are stored locally.
```

- [ ] **Step 5: Resolve dependencies and run the shell**

Run:

```bash
swift package resolve
swift run KHPlayer
```

Expected: dependency resolution succeeds and a minimal macOS window opens.

- [ ] **Step 6: Commit**

```bash
git add Package.swift README.md Sources
git commit -m "chore: bootstrap macOS SwiftUI player"
```

### Task 2: Add Domain Models And Errors

**Files:**
- Create: `Sources/KHPlayer/Domain/Models.swift`
- Create: `Sources/KHPlayer/Domain/KHError.swift`
- Test: `Tests/KHPlayerTests/PlaybackQueueTests.swift`

- [ ] **Step 1: Add domain models**

Use the exact `Models.swift` content from the Data Types section.

- [ ] **Step 2: Add error model**

Use the exact `KHError.swift` content from the Data Types section.

- [ ] **Step 3: Add a compilation test**

Create `Tests/KHPlayerTests/PlaybackQueueTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class PlaybackQueueTests: XCTestCase {
    func testTrackIdentityUsesStableID() {
        let url = URL(string: "https://downloads.khinsider.com/game-soundtracks/album/example/01.%2520Song.mp3")!
        let track = Track(
            id: "example/01-song",
            albumID: "example",
            number: 1,
            title: "Song",
            detailURL: url,
            duration: 123,
            mp3Size: "3.00 MB",
            flacSize: "9.00 MB"
        )

        XCTAssertEqual(track.id, "example/01-song")
        XCTAssertEqual(track.duration, 123)
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter PlaybackQueueTests
```

Expected: test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/Domain Tests/KHPlayerTests/PlaybackQueueTests.swift
git commit -m "feat: add player domain models"
```

### Task 3: Build KHInsider Request Layer

**Files:**
- Create: `Sources/KHPlayer/Networking/KHRequestBuilder.swift`
- Create: `Sources/KHPlayer/Networking/KHClient.swift`
- Test: `Tests/KHPlayerTests/KHRequestBuilderTests.swift`

- [ ] **Step 1: Write URL builder tests**

Create `Tests/KHPlayerTests/KHRequestBuilderTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class KHRequestBuilderTests: XCTestCase {
    func testSearchAlbumURL() throws {
        let url = try KHRequestBuilder.searchURL(query: "persona 5", type: .album, sort: .relevance)
        XCTAssertEqual(url.absoluteString, "https://downloads.khinsider.com/search?search=persona%205&type=album&sort=relevance")
    }

    func testSearchSongURL() throws {
        let url = try KHRequestBuilder.searchURL(query: "persona", type: .song, sort: .name)
        XCTAssertEqual(url.absoluteString, "https://downloads.khinsider.com/search?search=persona&type=song&sort=name")
    }

    func testRejectsEmptySearch() {
        XCTAssertThrowsError(try KHRequestBuilder.searchURL(query: "  ", type: .album, sort: .name))
    }
}
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter KHRequestBuilderTests
```

Expected: fails because `KHRequestBuilder` does not exist.

- [ ] **Step 3: Implement request builder**

Create `Sources/KHPlayer/Networking/KHRequestBuilder.swift`:

```swift
import Foundation

enum SearchType: String, Sendable {
    case album
    case song
}

enum SearchSort: String, Sendable {
    case name
    case timestamp
    case popularity
    case year
    case relevance
}

enum KHRequestBuilder {
    static let baseURL = URL(string: "https://downloads.khinsider.com")!

    static func searchURL(query: String, type: SearchType, sort: SearchSort) throws -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KHError.invalidURL("empty search query")
        }

        var components = URLComponents(url: baseURL.appending(path: "search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search", value: trimmed),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "sort", value: sort.rawValue)
        ]

        guard let url = components.url else {
            throw KHError.invalidURL(trimmed)
        }
        return url
    }
}
```

- [ ] **Step 4: Implement client**

Create `Sources/KHPlayer/Networking/KHClient.swift`:

```swift
import Foundation

final class KHClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func html(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("KHInsiderPlayerMac/0.1 (+https://downloads.khinsider.com/)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 403 {
                throw KHError.blockedByCloudflare
            }
            throw KHError.networkStatus(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            return String(decoding: data, as: UTF8.self)
        }
        return html
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter KHRequestBuilderTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/KHPlayer/Networking Tests/KHPlayerTests/KHRequestBuilderTests.swift
git commit -m "feat: add KHInsider request layer"
```

### Task 4: Parse Search Results

**Files:**
- Create: `Sources/KHPlayer/Parsing/SearchResultsParser.swift`
- Create: `Tests/KHPlayerTests/Fixtures/SearchPersonaAlbums.html`
- Test: `Tests/KHPlayerTests/SearchResultsParserTests.swift`

- [ ] **Step 1: Add fixture**

Create `Tests/KHPlayerTests/Fixtures/SearchPersonaAlbums.html`:

```html
<table class="albumList">
  <tr>
    <th></th><th>Album</th><th>Platform</th><th>Type</th><th>Year</th>
  </tr>
  <tr>
    <td class="albumIcon">
      <a href="/game-soundtracks/album/persona-1-the-complete-soundtrack">
        <img src="https://nu.vgmtreasurechest.com/soundtracks/persona-1-the-complete-soundtrack/thumbs_small/cover.png">
      </a>
    </td>
    <td>
      <a href="/game-soundtracks/album/persona-1-the-complete-soundtrack">Persona 1 - The Complete Soundtrack</a>
    </td>
    <td>
      <a href="/game-soundtracks/playstation">PS1</a>, <a href="/game-soundtracks/playstation-portable-psp">PSP</a>
    </td>
    <td>Compilation</td>
    <td>1996</td>
  </tr>
</table>
```

- [ ] **Step 2: Add parser tests**

Create `Tests/KHPlayerTests/SearchResultsParserTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class SearchResultsParserTests: XCTestCase {
    func testParsesAlbumRows() throws {
        let html = try fixture("SearchPersonaAlbums")
        let results = try SearchResultsParser.parse(html: html)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "persona-1-the-complete-soundtrack")
        XCTAssertEqual(results[0].title, "Persona 1 - The Complete Soundtrack")
        XCTAssertEqual(results[0].platforms, ["PS1", "PSP"])
        XCTAssertEqual(results[0].albumType, "Compilation")
        XCTAssertEqual(results[0].year, 1996)
        XCTAssertEqual(results[0].artworkURL?.host, "nu.vgmtreasurechest.com")
    }

    private func fixture(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }
}
```

- [ ] **Step 3: Run failing tests**

Run:

```bash
swift test --filter SearchResultsParserTests
```

Expected: fails because `SearchResultsParser` does not exist.

- [ ] **Step 4: Implement parser**

Create `Sources/KHPlayer/Parsing/SearchResultsParser.swift`:

```swift
import Foundation
import SwiftSoup

enum SearchResultsParser {
    static func parse(html: String) throws -> [AlbumSummary] {
        let document = try SwiftSoup.parse(html)
        let rows = try document.select("table.albumList tr").array().dropFirst()

        return try rows.compactMap { row in
            let albumLink = try row.select("td:nth-child(2) a[href^=/game-soundtracks/album/]").first()
            guard let albumLink else {
                return nil
            }

            let href = try albumLink.attr("href")
            let url = try absoluteURL(pathOrURL: href)
            let id = url.lastPathComponent
            let title = try albumLink.text().trimmingCharacters(in: .whitespacesAndNewlines)
            let imageSource = try row.select("td.albumIcon img").first()?.attr("src")
            let artworkURL = try imageSource.flatMap { try absoluteURL(pathOrURL: $0) }
            let platformLinks = try row.select("td:nth-child(3) a").array()
            let platforms = try platformLinks.map { try $0.text() }
            let albumType = try row.select("td:nth-child(4)").first()?.text().nilIfBlank
            let yearText = try row.select("td:nth-child(5)").first()?.text()
            let year = yearText.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

            return AlbumSummary(
                id: id,
                title: title,
                url: url,
                artworkURL: artworkURL,
                platforms: platforms,
                albumType: albumType,
                year: year,
                catalogNumber: nil
            )
        }
    }

    private static func absoluteURL(pathOrURL: String) throws -> URL {
        if let url = URL(string: pathOrURL), url.scheme != nil {
            return url
        }
        guard let url = URL(string: pathOrURL, relativeTo: KHRequestBuilder.baseURL)?.absoluteURL else {
            throw KHError.invalidURL(pathOrURL)
        }
        return url
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter SearchResultsParserTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/KHPlayer/Parsing/SearchResultsParser.swift Tests/KHPlayerTests/SearchResultsParserTests.swift Tests/KHPlayerTests/Fixtures/SearchPersonaAlbums.html
git commit -m "feat: parse KHInsider search results"
```

### Task 5: Parse Album Pages

**Files:**
- Create: `Sources/KHPlayer/Parsing/AlbumPageParser.swift`
- Create: `Tests/KHPlayerTests/Fixtures/PersonaVinylAlbum.html`
- Test: `Tests/KHPlayerTests/AlbumPageParserTests.swift`

- [ ] **Step 1: Add album fixture**

Create `Tests/KHPlayerTests/Fixtures/PersonaVinylAlbum.html`:

```html
<h2>Persona Vinyl Soundtrack</h2>
<p class="albuminfoAlternativeTitles">SMT Persona 1 Vinyl Soundtrack<br>Persona 1 Vinyl Soundtrack</p>
<p align="left">
  Platforms: <a href="/game-soundtracks/playstation">PS1</a>, <a href="/game-soundtracks/windows">Windows</a><br>
  Year: <b>2022</b><br>
  Published by: <a href="/game-soundtracks/publisher/iam8bit">iam8bit</a><br>
  <br>Number of Files: <b>23</b><br>
  Total Filesize: <b>87 MB</b> (MP3), <b>254 MB</b> (FLAC)<br>
  Date Added: <b>May 29th, 2024</b><br>
  Album type: <b><a href="/game-soundtracks/ost">Soundtrack</a></b><br>
</p>
<div class="albumImage">
  <a href="https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/folder.png">
    <img src="https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/thumbs/folder.png">
  </a>
</div>
<table id="songlist">
  <tr id="songlist_header">
    <th></th><th>#</th><th colspan="2">Song Name</th><th>MP3</th><th>FLAC</th><th></th><th></th>
  </tr>
  <tr>
    <td></td>
    <td align="right">1.</td>
    <td class="clickable-row"><a href="/game-soundtracks/album/persona-vinyl-soundtrack-2022/01.%2520Persona.mp3">Persona</a></td>
    <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-vinyl-soundtrack-2022/01.%2520Persona.mp3">3:06</a></td>
    <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-vinyl-soundtrack-2022/01.%2520Persona.mp3">5.43 MB</a></td>
    <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-vinyl-soundtrack-2022/01.%2520Persona.mp3">14.34 MB</a></td>
    <td></td><td></td>
  </tr>
  <tr id="songlist_footer">
    <th colspan="3">Total:</th><th>45m 11s</th><th>87 MB</th><th>254 MB</th><th></th><th></th>
  </tr>
</table>
<h2>Description</h2>
<p>Vinyl rip of Iam8bit's release.</p>
```

- [ ] **Step 2: Add parser tests**

Create `Tests/KHPlayerTests/AlbumPageParserTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class AlbumPageParserTests: XCTestCase {
    func testParsesAlbumMetadataAndTracks() throws {
        let html = try fixture("PersonaVinylAlbum")
        let url = URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022")!
        let album = try AlbumPageParser.parse(html: html, url: url)

        XCTAssertEqual(album.id, "persona-vinyl-soundtrack-2022")
        XCTAssertEqual(album.title, "Persona Vinyl Soundtrack")
        XCTAssertEqual(album.alternativeTitles, ["SMT Persona 1 Vinyl Soundtrack", "Persona 1 Vinyl Soundtrack"])
        XCTAssertEqual(album.platforms, ["PS1", "Windows"])
        XCTAssertEqual(album.year, 2022)
        XCTAssertEqual(album.publisher, "iam8bit")
        XCTAssertEqual(album.albumType, "Soundtrack")
        XCTAssertEqual(album.fileCount, 23)
        XCTAssertEqual(album.totalMP3Size, "87 MB")
        XCTAssertEqual(album.totalFLACSize, "254 MB")
        XCTAssertEqual(album.dateAdded, "May 29th, 2024")
        XCTAssertEqual(album.tracks.count, 1)
        XCTAssertEqual(album.tracks[0].number, 1)
        XCTAssertEqual(album.tracks[0].title, "Persona")
        XCTAssertEqual(album.tracks[0].duration, 186)
        XCTAssertEqual(album.tracks[0].mp3Size, "5.43 MB")
        XCTAssertEqual(album.tracks[0].flacSize, "14.34 MB")
    }

    private func fixture(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }
}
```

- [ ] **Step 3: Run failing tests**

Run:

```bash
swift test --filter AlbumPageParserTests
```

Expected: fails because `AlbumPageParser` does not exist.

- [ ] **Step 4: Implement album parser**

Create `Sources/KHPlayer/Parsing/AlbumPageParser.swift` with these public entry points:

```swift
import Foundation
import SwiftSoup

enum AlbumPageParser {
    static func parse(html: String, url: URL) throws -> AlbumDetail {
        let document = try SwiftSoup.parse(html)
        let id = url.lastPathComponent
        let title = try document.select("h2").first()?.text()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title, !title.isEmpty else {
            throw KHError.parserMissingElement("album title")
        }

        let alternativeTitles = try parseAlternativeTitles(document)
        let metadataText = try document.select("p[align=left]").first()?.html() ?? ""
        let metadata = parseMetadata(html: metadataText)
        let platforms = try document.select("p[align=left] a[href^=/game-soundtracks/]").array()
            .filter { try !$0.attr("href").contains("/publisher/") && !$0.attr("href").contains("/ost") }
            .map { try $0.text() }
        let artworkURL = try document.select(".albumImage a").first().flatMap { element in
            try URL(string: element.attr("href"))
        }
        let tracks = try parseTracks(document: document, albumID: id)

        return AlbumDetail(
            id: id,
            title: title,
            url: url,
            alternativeTitles: alternativeTitles,
            platforms: platforms,
            year: metadata.year,
            publisher: metadata.publisher,
            albumType: metadata.albumType,
            fileCount: metadata.fileCount,
            totalDuration: metadata.totalDuration,
            totalMP3Size: metadata.totalMP3Size,
            totalFLACSize: metadata.totalFLACSize,
            dateAdded: metadata.dateAdded,
            artworkURL: artworkURL,
            description: try parseDescription(document),
            tracks: tracks
        )
    }

    private static func parseAlternativeTitles(_ document: Document) throws -> [String] {
        guard let html = try document.select(".albuminfoAlternativeTitles").first()?.html() else {
            return []
        }
        return html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseTracks(document: Document, albumID: String) throws -> [Track] {
        let rows = try document.select("table#songlist tr").array()
        return try rows.compactMap { row in
            if try row.id() == "songlist_header" || row.id() == "songlist_footer" {
                return nil
            }

            let cells = try row.select("td").array()
            guard cells.count >= 6 else {
                return nil
            }

            let numberText = try cells[1].text().replacingOccurrences(of: ".", with: "")
            guard let number = Int(numberText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }

            let titleLink = try cells[2].select("a").first()
            guard let titleLink else {
                return nil
            }

            let href = try titleLink.attr("href")
            let detailURL = URL(string: href, relativeTo: KHRequestBuilder.baseURL)!.absoluteURL
            let title = try titleLink.text()
            let duration = parseDuration(try cells[3].text())
            let mp3Size = try cells[4].text().trimmedNonEmpty
            let flacSize = try cells[5].text().trimmedNonEmpty

            return Track(
                id: "\(albumID)-\(number)",
                albumID: albumID,
                number: number,
                title: title,
                detailURL: detailURL,
                duration: duration,
                mp3Size: mp3Size,
                flacSize: flacSize
            )
        }
    }
}
```

Complete the private helpers in the same file:

```swift
private struct AlbumMetadata {
    var year: Int?
    var publisher: String?
    var albumType: String?
    var fileCount: Int?
    var totalDuration: TimeInterval?
    var totalMP3Size: String?
    var totalFLACSize: String?
    var dateAdded: String?
}

private extension AlbumPageParser {
    static func parseMetadata(html: String) -> AlbumMetadata {
        let text = html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        var metadata = AlbumMetadata()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("Year:") {
                metadata.year = Int(trimmed.replacingOccurrences(of: "Year:", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            } else if trimmed.hasPrefix("Published by:") {
                metadata.publisher = trimmed.replacingOccurrences(of: "Published by:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Number of Files:") {
                metadata.fileCount = Int(trimmed.replacingOccurrences(of: "Number of Files:", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            } else if trimmed.hasPrefix("Date Added:") {
                metadata.dateAdded = trimmed.replacingOccurrences(of: "Date Added:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Album type:") {
                metadata.albumType = trimmed.replacingOccurrences(of: "Album type:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Total Filesize:") {
                let sizes = trimmed.replacingOccurrences(of: "Total Filesize:", with: "").components(separatedBy: ",")
                metadata.totalMP3Size = sizes.first?.replacingOccurrences(of: "(MP3)", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if sizes.count > 1 {
                    metadata.totalFLACSize = sizes[1].replacingOccurrences(of: "(FLAC)", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return metadata
    }

    static func parseDescription(_ document: Document) throws -> String? {
        let headings = try document.select("h2").array()
        guard let descriptionHeading = try headings.first(where: { try $0.text() == "Description" }),
              let paragraph = try descriptionHeading.nextElementSibling(),
              try paragraph.tagName() == "p"
        else {
            return nil
        }
        return try paragraph.text().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseDuration(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return TimeInterval(parts[0] * 60 + parts[1])
        }
        if parts.count == 3 {
            return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        }
        return nil
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter AlbumPageParserTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/KHPlayer/Parsing/AlbumPageParser.swift Tests/KHPlayerTests/AlbumPageParserTests.swift Tests/KHPlayerTests/Fixtures/PersonaVinylAlbum.html
git commit -m "feat: parse KHInsider album pages"
```

### Task 6: Resolve Track Streams

**Files:**
- Create: `Sources/KHPlayer/Parsing/TrackDetailParser.swift`
- Create: `Sources/KHPlayer/Playback/StreamResolver.swift`
- Create: `Tests/KHPlayerTests/Fixtures/PersonaTrackDetail.html`
- Test: `Tests/KHPlayerTests/TrackDetailParserTests.swift`

- [ ] **Step 1: Add track detail fixture**

Create `Tests/KHPlayerTests/Fixtures/PersonaTrackDetail.html`:

```html
<p align="left">
  Album name: <b>Persona Vinyl Soundtrack (2022)</b><br>
  Song name: <b>Persona</b>
</p>
<p>
  <a href="https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/kjtnjhjw/01.%20Persona.mp3">
    <span class="songDownloadLink">Click here to download as MP3</span>
  </a> (5.43 MB)
</p>
<p>
  <a href="https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/kjtnjhjw/01.%20Persona.flac">
    <span class="songDownloadLink">Click here to download as FLAC</span>
  </a> (14.34 MB)
</p>
<audio id="audio" controls preload="auto" src="https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/kjtnjhjw/01.%20Persona.mp3"></audio>
```

- [ ] **Step 2: Add parser tests**

Create `Tests/KHPlayerTests/TrackDetailParserTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class TrackDetailParserTests: XCTestCase {
    func testParsesMP3AndFLACLinks() throws {
        let html = try fixture("PersonaTrackDetail")
        let streams = try TrackDetailParser.parse(html: html, trackID: "persona-vinyl-soundtrack-2022-1")

        XCTAssertEqual(streams.count, 2)
        XCTAssertEqual(streams[0].format, .mp3)
        XCTAssertEqual(streams[0].sizeLabel, "5.43 MB")
        XCTAssertEqual(streams[0].sourceURL.pathExtension, "mp3")
        XCTAssertEqual(streams[1].format, .flac)
        XCTAssertEqual(streams[1].sizeLabel, "14.34 MB")
        XCTAssertEqual(streams[1].sourceURL.pathExtension, "flac")
    }

    private func fixture(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }
}
```

- [ ] **Step 3: Run failing tests**

Run:

```bash
swift test --filter TrackDetailParserTests
```

Expected: fails because `TrackDetailParser` does not exist.

- [ ] **Step 4: Implement parser**

Create `Sources/KHPlayer/Parsing/TrackDetailParser.swift`:

```swift
import Foundation
import SwiftSoup

enum TrackDetailParser {
    static func parse(html: String, trackID: String) throws -> [ResolvedStream] {
        let document = try SwiftSoup.parse(html)
        let links = try document.select("a[href]").array()

        return try links.compactMap { link in
            let href = try link.attr("href")
            guard let url = URL(string: href), url.host?.contains("vgmtreasurechest.com") == true else {
                return nil
            }

            let pathExtension = url.pathExtension.lowercased()
            let format: ResolvedStream.Format
            if pathExtension == "mp3" {
                format = .mp3
            } else if pathExtension == "flac" {
                format = .flac
            } else {
                return nil
            }

            let parentText = try link.parent()?.text() ?? ""
            let size = parentText.firstParenthesizedValue
            return ResolvedStream(
                trackID: trackID,
                sourceURL: url,
                format: format,
                sizeLabel: size,
                contentLength: nil,
                etag: nil
            )
        }
    }
}

private extension String {
    var firstParenthesizedValue: String? {
        guard let open = firstIndex(of: "("), let close = firstIndex(of: ")"), open < close else {
            return nil
        }
        return String(self[index(after: open)..<close])
    }
}
```

- [ ] **Step 5: Implement stream resolver**

Create `Sources/KHPlayer/Playback/StreamResolver.swift`:

```swift
import Foundation

final class StreamResolver: Sendable {
    private let client: KHClient

    init(client: KHClient) {
        self.client = client
    }

    func resolve(track: Track, preferredFormat: ResolvedStream.Format) async throws -> ResolvedStream {
        let html = try await client.html(from: track.detailURL)
        let streams = try TrackDetailParser.parse(html: html, trackID: track.id)

        if let preferred = streams.first(where: { $0.format == preferredFormat }) {
            return preferred
        }
        if let mp3 = streams.first(where: { $0.format == .mp3 }) {
            return mp3
        }
        throw KHError.streamNotFound(trackTitle: track.title)
    }
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter TrackDetailParserTests
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/KHPlayer/Parsing/TrackDetailParser.swift Sources/KHPlayer/Playback/StreamResolver.swift Tests/KHPlayerTests/TrackDetailParserTests.swift Tests/KHPlayerTests/Fixtures/PersonaTrackDetail.html
git commit -m "feat: resolve playable track streams"
```

### Task 7: Implement Local Library Store

**Files:**
- Create: `Sources/KHPlayer/Persistence/Records.swift`
- Create: `Sources/KHPlayer/Persistence/SchemaMigrator.swift`
- Create: `Sources/KHPlayer/Persistence/LibraryStore.swift`
- Test: `Tests/KHPlayerTests/LibraryStoreTests.swift`

- [ ] **Step 1: Add store tests**

Create `Tests/KHPlayerTests/LibraryStoreTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class LibraryStoreTests: XCTestCase {
    func testFavoriteAlbumRoundTrip() throws {
        let store = try LibraryStore.inMemory()
        try store.setAlbumFavorite(albumID: "persona-vinyl-soundtrack-2022", isFavorite: true)
        XCTAssertTrue(try store.isAlbumFavorite(albumID: "persona-vinyl-soundtrack-2022"))

        try store.setAlbumFavorite(albumID: "persona-vinyl-soundtrack-2022", isFavorite: false)
        XCTAssertFalse(try store.isAlbumFavorite(albumID: "persona-vinyl-soundtrack-2022"))
    }

    func testHistoryKeepsLatestPlayAtTop() throws {
        let store = try LibraryStore.inMemory()
        try store.recordPlay(trackID: "track-1", albumID: "album-1", title: "One")
        try store.recordPlay(trackID: "track-2", albumID: "album-1", title: "Two")

        let history = try store.recentHistory(limit: 10)
        XCTAssertEqual(history.map(\.trackID), ["track-2", "track-1"])
    }
}
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter LibraryStoreTests
```

Expected: fails because `LibraryStore` does not exist.

- [ ] **Step 3: Implement records**

Create `Sources/KHPlayer/Persistence/Records.swift`:

```swift
import Foundation
import GRDB

struct HistoryEntry: FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "history"

    var trackID: String
    var albumID: String
    var title: String
    var playedAt: Date
}
```

- [ ] **Step 4: Implement schema migrator**

Create `Sources/KHPlayer/Persistence/SchemaMigrator.swift`:

```swift
import GRDB

enum SchemaMigrator {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "favorite_albums") { table in
                table.column("albumID", .text).primaryKey()
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "favorite_tracks") { table in
                table.column("trackID", .text).primaryKey()
                table.column("albumID", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "history") { table in
                table.column("trackID", .text).primaryKey()
                table.column("albumID", .text).notNull()
                table.column("title", .text).notNull()
                table.column("playedAt", .datetime).notNull().indexed()
            }
            try db.create(table: "playlists") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "playlist_items") { table in
                table.column("playlistID", .text).notNull().indexed()
                table.column("trackID", .text).notNull()
                table.column("albumID", .text).notNull()
                table.column("position", .integer).notNull()
                table.primaryKey(["playlistID", "trackID"])
            }
        }
        return migrator
    }
}
```

- [ ] **Step 5: Implement library store**

Create `Sources/KHPlayer/Persistence/LibraryStore.swift`:

```swift
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
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KHInsiderPlayerMac", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let dbURL = base.appending(path: "Library.sqlite")
        return try LibraryStore(dbQueue: DatabaseQueue(path: dbURL.path))
    }

    func setAlbumFavorite(albumID: String, isFavorite: Bool) throws {
        try dbQueue.write { db in
            if isFavorite {
                try db.execute(sql: "INSERT OR REPLACE INTO favorite_albums (albumID, createdAt) VALUES (?, ?)", arguments: [albumID, Date()])
            } else {
                try db.execute(sql: "DELETE FROM favorite_albums WHERE albumID = ?", arguments: [albumID])
            }
        }
    }

    func isAlbumFavorite(albumID: String) throws -> Bool {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM favorite_albums WHERE albumID = ?", arguments: [albumID]) ?? 0 > 0
        }
    }

    func recordPlay(trackID: String, albumID: String, title: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO history (trackID, albumID, title, playedAt) VALUES (?, ?, ?, ?)",
                arguments: [trackID, albumID, title, Date()]
            )
        }
    }

    func recentHistory(limit: Int) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry.fetchAll(db, sql: "SELECT * FROM history ORDER BY playedAt DESC LIMIT ?", arguments: [limit])
        }
    }
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter LibraryStoreTests
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/KHPlayer/Persistence Tests/KHPlayerTests/LibraryStoreTests.swift
git commit -m "feat: add local library store"
```

### Task 8: Implement Active Track Cache

**Files:**
- Create: `Sources/KHPlayer/Playback/ActiveTrackCache.swift`
- Test: `Tests/KHPlayerTests/ActiveTrackCacheTests.swift`

- [ ] **Step 1: Add cache tests**

Create `Tests/KHPlayerTests/ActiveTrackCacheTests.swift`:

```swift
import XCTest
@testable import KHPlayer

final class ActiveTrackCacheTests: XCTestCase {
    func testWritingChunksRespectsLimit() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 8, chunkSize: 4)
        try cache.prepareForTrack(cacheKey: "track-a")

        try cache.store(data: Data([0, 1, 2, 3]), rangeStart: 0)
        try cache.store(data: Data([4, 5, 6, 7]), rangeStart: 4)
        try cache.store(data: Data([8, 9, 10, 11]), rangeStart: 8)

        XCTAssertLessThanOrEqual(try cache.currentSize(), 8)
        XCTAssertNil(try cache.data(for: 0..<4))
        XCTAssertEqual(try cache.data(for: 4..<8), Data([4, 5, 6, 7]))
        XCTAssertEqual(try cache.data(for: 8..<12), Data([8, 9, 10, 11]))
    }

    func testPrepareForNewTrackClearsOldChunks() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = try ActiveTrackCache(directory: directory, limitBytes: 16, chunkSize: 4)
        try cache.prepareForTrack(cacheKey: "track-a")
        try cache.store(data: Data([0, 1, 2, 3]), rangeStart: 0)

        try cache.prepareForTrack(cacheKey: "track-b")
        XCTAssertEqual(try cache.currentSize(), 0)
    }
}
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter ActiveTrackCacheTests
```

Expected: fails because `ActiveTrackCache` does not exist.

- [ ] **Step 3: Implement bounded chunk cache**

Create `Sources/KHPlayer/Playback/ActiveTrackCache.swift`:

```swift
import Foundation

final class ActiveTrackCache {
    private struct Chunk: Codable {
        let start: Int64
        let length: Int
        var lastAccess: Date
    }

    private let directory: URL
    private let limitBytes: Int64
    private let chunkSize: Int64
    private var chunks: [Int64: Chunk] = [:]

    init(directory: URL, limitBytes: Int64, chunkSize: Int64 = 512 * 1024) throws {
        guard limitBytes >= chunkSize else {
            throw KHError.cacheLimitTooSmall
        }
        self.directory = directory
        self.limitBytes = limitBytes
        self.chunkSize = chunkSize
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func prepareForTrack(cacheKey: String) throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        chunks.removeAll()
    }

    func store(data: Data, rangeStart: Int64) throws {
        let normalizedStart = (rangeStart / chunkSize) * chunkSize
        let url = chunkURL(start: normalizedStart)
        try data.write(to: url, options: .atomic)
        chunks[normalizedStart] = Chunk(start: normalizedStart, length: data.count, lastAccess: Date())
        try enforceLimit()
    }

    func data(for range: Range<Int64>) throws -> Data? {
        let normalizedStart = (range.lowerBound / chunkSize) * chunkSize
        guard var chunk = chunks[normalizedStart] else {
            return nil
        }
        let url = chunkURL(start: normalizedStart)
        let data = try Data(contentsOf: url)
        let offset = Int(range.lowerBound - normalizedStart)
        let end = min(data.count, Int(range.upperBound - normalizedStart))
        guard offset >= 0, offset < end, end <= data.count else {
            return nil
        }
        chunk.lastAccess = Date()
        chunks[normalizedStart] = chunk
        return data.subdata(in: offset..<end)
    }

    func currentSize() throws -> Int64 {
        try chunks.values.reduce(Int64(0)) { $0 + Int64($1.length) }
    }

    private func enforceLimit() throws {
        while try currentSize() > limitBytes {
            guard let victim = chunks.values.min(by: { $0.lastAccess < $1.lastAccess }) else {
                return
            }
            try? FileManager.default.removeItem(at: chunkURL(start: victim.start))
            chunks.removeValue(forKey: victim.start)
        }
    }

    private func chunkURL(start: Int64) -> URL {
        directory.appending(path: "chunk-\(start).bin")
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter ActiveTrackCacheTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/Playback/ActiveTrackCache.swift Tests/KHPlayerTests/ActiveTrackCacheTests.swift
git commit -m "feat: add bounded active track cache"
```

### Task 9: Add Caching Stream Resource Loader

**Files:**
- Create: `Sources/KHPlayer/Playback/CachingStreamResourceLoader.swift`
- Modify: `Sources/KHPlayer/Playback/ActiveTrackCache.swift`

- [ ] **Step 1: Define custom URL mapping**

In `CachingStreamResourceLoader.swift`, create:

```swift
import AVFoundation
import Foundation

final class CachingStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let sourceURL: URL
    private let cache: ActiveTrackCache
    private let session: URLSession
    private let contentType: String
    private let contentLength: Int64?

    init(
        sourceURL: URL,
        cache: ActiveTrackCache,
        session: URLSession = .shared,
        contentType: String = AVFileType.mp3.rawValue,
        contentLength: Int64? = nil
    ) {
        self.sourceURL = sourceURL
        self.cache = cache
        self.session = session
        self.contentType = contentType
        self.contentLength = contentLength
    }

    static func assetURL(for stream: ResolvedStream) -> URL {
        var components = URLComponents()
        components.scheme = "khcache"
        components.host = "track"
        components.path = "/" + stream.trackID
        components.queryItems = [
            URLQueryItem(name: "format", value: stream.format.rawValue)
        ]
        return components.url!
    }
}
```

- [ ] **Step 2: Implement loading request handling**

Add this delegate implementation:

```swift
extension CachingStreamResourceLoader {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        Task {
            do {
                try await handle(loadingRequest)
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }
        return true
    }

    private func handle(_ loadingRequest: AVAssetResourceLoadingRequest) async throws {
        if let contentInformationRequest = loadingRequest.contentInformationRequest {
            contentInformationRequest.contentType = contentType
            contentInformationRequest.isByteRangeAccessSupported = true
            if let contentLength {
                contentInformationRequest.contentLength = contentLength
            }
        }

        guard let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading()
            return
        }

        let start = dataRequest.requestedOffset
        let requestedLength = Int64(dataRequest.requestedLength)
        let end = start + requestedLength

        if let cached = try cache.data(for: start..<end) {
            dataRequest.respond(with: cached)
            loadingRequest.finishLoading()
            return
        }

        let fetched = try await fetchRange(start: start, endExclusive: end)
        try cache.store(data: fetched, rangeStart: start)
        dataRequest.respond(with: fetched)
        loadingRequest.finishLoading()
    }

    private func fetchRange(start: Int64, endExclusive: Int64) async throws -> Data {
        var request = URLRequest(url: sourceURL)
        request.setValue("bytes=\(start)-\(endExclusive - 1)", forHTTPHeaderField: "Range")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }
        guard http.statusCode == 206 || http.statusCode == 200 else {
            throw KHError.networkStatus(http.statusCode)
        }
        return data
    }
}
```

- [ ] **Step 3: Add cancellation**

Add:

```swift
extension CachingStreamResourceLoader {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        loadingRequest.finishLoading()
    }
}
```

- [ ] **Step 4: Compile**

Run:

```bash
swift test
```

Expected: all tests pass and `CachingStreamResourceLoader` compiles.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/Playback/CachingStreamResourceLoader.swift Sources/KHPlayer/Playback/ActiveTrackCache.swift
git commit -m "feat: stream through bounded cache loader"
```

### Task 10: Add Playback Engine

**Files:**
- Create: `Sources/KHPlayer/Playback/PlaybackQueue.swift`
- Create: `Sources/KHPlayer/Playback/PlaybackEngine.swift`
- Create: `Sources/KHPlayer/Playback/NowPlayingBridge.swift`
- Modify: `Tests/KHPlayerTests/PlaybackQueueTests.swift`

- [ ] **Step 1: Add queue tests**

Extend `Tests/KHPlayerTests/PlaybackQueueTests.swift` with:

```swift
func testQueueAdvancesSequentially() {
    var queue = PlaybackQueue(items: ["a", "b", "c"], currentIndex: 0)
    XCTAssertEqual(queue.current, "a")
    XCTAssertEqual(queue.advance(), "b")
    XCTAssertEqual(queue.advance(), "c")
    XCTAssertNil(queue.advance())
}

func testRepeatAllWrapsAtEnd() {
    var queue = PlaybackQueue(items: ["a", "b"], currentIndex: 1, repeatMode: .all)
    XCTAssertEqual(queue.advance(), "a")
}
```

- [ ] **Step 2: Implement playback queue**

Create `Sources/KHPlayer/Playback/PlaybackQueue.swift`:

```swift
import Foundation

enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case one
    case all
}

struct PlaybackQueue<Item: Equatable> {
    var items: [Item]
    var currentIndex: Int
    var repeatMode: RepeatMode = .off
    var isShuffleEnabled = false

    var current: Item? {
        guard items.indices.contains(currentIndex) else {
            return nil
        }
        return items[currentIndex]
    }

    mutating func advance() -> Item? {
        guard !items.isEmpty else {
            return nil
        }
        if repeatMode == .one {
            return current
        }
        let nextIndex = currentIndex + 1
        if items.indices.contains(nextIndex) {
            currentIndex = nextIndex
            return current
        }
        if repeatMode == .all {
            currentIndex = 0
            return current
        }
        return nil
    }
}
```

- [ ] **Step 3: Implement playback engine skeleton**

Create `Sources/KHPlayer/Playback/PlaybackEngine.swift`:

```swift
import AVFoundation
import Foundation

@MainActor
final class PlaybackEngine: ObservableObject {
    @Published private(set) var currentItem: PlaybackItem?
    @Published private(set) var isPlaying = false
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffleEnabled = false

    private let resolver: StreamResolver
    private let cache: ActiveTrackCache
    private var player: AVPlayer?
    private var resourceLoader: CachingStreamResourceLoader?
    private var queue = PlaybackQueue<PlaybackItem>(items: [], currentIndex: 0)

    init(resolver: StreamResolver, cache: ActiveTrackCache) {
        self.resolver = resolver
        self.cache = cache
    }

    func play(album: AlbumDetail, startingAt track: Track, preferredFormat: ResolvedStream.Format) async throws {
        let items = album.tracks.map { PlaybackItem(id: $0.id, album: album, track: $0, preferredFormat: preferredFormat) }
        let index = items.firstIndex(where: { $0.track.id == track.id }) ?? 0
        queue = PlaybackQueue(items: items, currentIndex: index, repeatMode: repeatMode, isShuffleEnabled: isShuffleEnabled)
        try await playCurrent()
    }

    func togglePlayPause() {
        guard let player else {
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func next() async throws {
        guard queue.advance() != nil else {
            player?.pause()
            isPlaying = false
            return
        }
        try await playCurrent()
    }

    private func playCurrent() async throws {
        guard let item = queue.current else {
            return
        }
        currentItem = item
        let stream = try await resolver.resolve(track: item.track, preferredFormat: item.preferredFormat)
        try cache.prepareForTrack(cacheKey: stream.trackID)

        let loader = CachingStreamResourceLoader(sourceURL: stream.sourceURL, cache: cache)
        let assetURL = CachingStreamResourceLoader.assetURL(for: stream)
        let asset = AVURLAsset(url: assetURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "KHPlayer.ResourceLoader"))
        resourceLoader = loader

        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        isPlaying = true
    }
}
```

- [ ] **Step 4: Add Now Playing bridge**

Create `Sources/KHPlayer/Playback/NowPlayingBridge.swift`:

```swift
import Foundation
import MediaPlayer

@MainActor
final class NowPlayingBridge {
    func update(item: PlaybackItem?) {
        guard let item else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.track.title,
            MPMediaItemPropertyAlbumTitle: item.album.title
        ]
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter PlaybackQueueTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/KHPlayer/Playback Tests/KHPlayerTests/PlaybackQueueTests.swift
git commit -m "feat: add streaming playback engine"
```

### Task 11: Wire App State

**Files:**
- Create: `Sources/KHPlayer/App/AppState.swift`
- Create: `Sources/KHPlayer/App/EnvironmentValues.swift`
- Modify: `Sources/KHPlayer/App/KHPlayerApp.swift`

- [ ] **Step 1: Add AppState**

Create `Sources/KHPlayer/App/AppState.swift`:

```swift
import Foundation

@MainActor
final class AppState: ObservableObject {
    let client: KHClient
    let resolver: StreamResolver
    let store: LibraryStore
    let playbackEngine: PlaybackEngine

    @Published var preferredFormat: ResolvedStream.Format = .mp3
    @Published var cacheLimitBytes: Int64 = 256 * 1024 * 1024

    init() throws {
        client = KHClient()
        resolver = StreamResolver(client: client)
        store = try LibraryStore.appStore()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "com.bada.khinsider-player-mac", directoryHint: .isDirectory)
            .appending(path: "ActiveTrackCache", directoryHint: .isDirectory)
        let cache = try ActiveTrackCache(directory: cacheDirectory, limitBytes: cacheLimitBytes)
        playbackEngine = PlaybackEngine(resolver: resolver, cache: cache)
    }
}
```

- [ ] **Step 2: Add environment key**

Create `Sources/KHPlayer/App/EnvironmentValues.swift`:

```swift
import SwiftUI

private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
```

- [ ] **Step 3: Inject AppState**

Modify `Sources/KHPlayer/App/KHPlayerApp.swift`:

```swift
import SwiftUI

@main
struct KHPlayerApp: App {
    @StateObject private var appState: AppState

    init() {
        do {
            _appState = StateObject(wrappedValue: try AppState())
        } catch {
            fatalError("Failed to initialize KHPlayer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appState, appState)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}
```

- [ ] **Step 4: Compile**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/App
git commit -m "feat: wire application state"
```

### Task 12: Build Search UI

**Files:**
- Create: `Sources/KHPlayer/Features/Search/SearchViewModel.swift`
- Create: `Sources/KHPlayer/Features/Search/SearchView.swift`
- Modify: `Sources/KHPlayer/Features/Shell/ContentView.swift`

- [ ] **Step 1: Add view model**

Create `Sources/KHPlayer/Features/Search/SearchViewModel.swift`:

```swift
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [AlbumSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: KHClient

    init(client: KHClient) {
        self.client = client
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let url = try KHRequestBuilder.searchURL(query: trimmed, type: .album, sort: .relevance)
            let html = try await client.html(from: url)
            results = try SearchResultsParser.parse(html: html)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add search view**

Create `Sources/KHPlayer/Features/Search/SearchView.swift`:

```swift
import SwiftUI

struct SearchView: View {
    @StateObject var viewModel: SearchViewModel
    let onOpenAlbum: (AlbumSummary) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search albums", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
                Button("Search") {
                    Task { await viewModel.search() }
                }
            }
            .padding()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.results) { album in
                    Button {
                        onOpenAlbum(album)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(album.title)
                            Text([album.year.map(String.init), album.albumType].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Wire ContentView**

Modify `Sources/KHPlayer/Features/Shell/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @Environment(\.appState) private var appState
    @State private var selectedAlbum: AlbumSummary?

    var body: some View {
        NavigationSplitView {
            List {
                Label("Search", systemImage: "magnifyingglass")
                Label("Favorites", systemImage: "heart")
                Label("History", systemImage: "clock")
                Label("Settings", systemImage: "gearshape")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            if let appState {
                SearchView(viewModel: SearchViewModel(client: appState.client)) { album in
                    selectedAlbum = album
                }
            } else {
                Text("App state unavailable")
            }
        }
    }
}
```

- [ ] **Step 4: Run app**

Run:

```bash
swift run KHPlayer
```

Expected: sidebar and search field render. Searching "persona" returns album rows unless KHInsider blocks the request.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/Features
git commit -m "feat: add search interface"
```

### Task 13: Build Album Detail UI

**Files:**
- Create: `Sources/KHPlayer/Features/Album/AlbumDetailViewModel.swift`
- Create: `Sources/KHPlayer/Features/Album/AlbumDetailView.swift`
- Modify: `Sources/KHPlayer/Features/Shell/ContentView.swift`

- [ ] **Step 1: Add album detail view model**

Create `Sources/KHPlayer/Features/Album/AlbumDetailViewModel.swift`:

```swift
import Foundation

@MainActor
final class AlbumDetailViewModel: ObservableObject {
    @Published var album: AlbumDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: KHClient
    private let summary: AlbumSummary

    init(summary: AlbumSummary, client: KHClient) {
        self.summary = summary
        self.client = client
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let html = try await client.html(from: summary.url)
            album = try AlbumPageParser.parse(html: html, url: summary.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add album detail view**

Create `Sources/KHPlayer/Features/Album/AlbumDetailView.swift`:

```swift
import SwiftUI

struct AlbumDetailView: View {
    @StateObject var viewModel: AlbumDetailViewModel
    let onPlay: (AlbumDetail, Track) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
            } else if let album = viewModel.album {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 20) {
                        AsyncImage(url: album.artworkURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(.quaternary)
                        }
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(album.title).font(.largeTitle).fontWeight(.semibold)
                            Text(album.platforms.joined(separator: ", ")).foregroundStyle(.secondary)
                            Text([album.year.map(String.init), album.albumType, album.publisher].compactMap { $0 }.joined(separator: " · "))
                                .foregroundStyle(.secondary)
                            Button {
                                if let first = album.tracks.first {
                                    onPlay(album, first)
                                }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                        }
                    }
                    .padding([.top, .horizontal])

                    List(album.tracks) { track in
                        HStack {
                            Text("\(track.number)")
                                .frame(width: 32, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            Button(track.title) {
                                onPlay(album, track)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            if let duration = track.duration {
                                Text(format(duration))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            } else {
                Color.clear.task { await viewModel.load() }
            }
        }
    }

    private func format(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
```

- [ ] **Step 3: Wire selection**

Modify `ContentView` so `selectedAlbum` opens `AlbumDetailView`:

```swift
if let appState {
    if let selectedAlbum {
        AlbumDetailView(
            viewModel: AlbumDetailViewModel(summary: selectedAlbum, client: appState.client)
        ) { album, track in
            Task {
                try? await appState.playbackEngine.play(album: album, startingAt: track, preferredFormat: appState.preferredFormat)
            }
        }
    } else {
        SearchView(viewModel: SearchViewModel(client: appState.client)) { album in
            selectedAlbum = album
        }
    }
} else {
    Text("App state unavailable")
}
```

- [ ] **Step 4: Run app**

Run:

```bash
swift run KHPlayer
```

Expected: selecting a search result loads album detail and lists tracks.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/Features/Album Sources/KHPlayer/Features/Shell/ContentView.swift
git commit -m "feat: add album detail interface"
```

### Task 14: Build Mini Player

**Files:**
- Create: `Sources/KHPlayer/Features/Player/MiniPlayerView.swift`
- Modify: `Sources/KHPlayer/Features/Shell/ContentView.swift`

- [ ] **Step 1: Add mini player view**

Create `Sources/KHPlayer/Features/Player/MiniPlayerView.swift`:

```swift
import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playbackEngine: PlaybackEngine

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text(playbackEngine.currentItem?.track.title ?? "Not Playing")
                    .font(.headline)
                    .lineLimit(1)
                Text(playbackEngine.currentItem?.album.title ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                playbackEngine.togglePlayPause()
            } label: {
                Image(systemName: playbackEngine.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderless)

            Button {
                Task { try? await playbackEngine.next() }
            } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .frame(height: 64)
        .background(.bar)
    }
}
```

- [ ] **Step 2: Attach mini player**

Wrap the detail area in `ContentView` with:

```swift
VStack(spacing: 0) {
    detailContent
    if let appState {
        Divider()
        MiniPlayerView(playbackEngine: appState.playbackEngine)
    }
}
```

Move the existing detail branch into a private `@ViewBuilder var detailContent: some View`.

- [ ] **Step 3: Run app**

Run:

```bash
swift run KHPlayer
```

Expected: bottom mini player is always visible and reflects the current track after playback starts.

- [ ] **Step 4: Commit**

```bash
git add Sources/KHPlayer/Features/Player Sources/KHPlayer/Features/Shell/ContentView.swift
git commit -m "feat: add persistent mini player"
```

### Task 15: Add Settings And Local Library Views

**Files:**
- Create: `Sources/KHPlayer/Features/Settings/SettingsView.swift`
- Create: `Sources/KHPlayer/Features/Library/LocalLibraryViews.swift`
- Modify: `Sources/KHPlayer/Features/Shell/SidebarView.swift`
- Modify: `Sources/KHPlayer/Features/Shell/ContentView.swift`

- [ ] **Step 1: Add settings view**

Create `Sources/KHPlayer/Features/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.appState) private var appState

    var body: some View {
        Form {
            Picker("Preferred Format", selection: bindingFormat) {
                Text("MP3").tag(ResolvedStream.Format.mp3)
                Text("FLAC").tag(ResolvedStream.Format.flac)
            }

            Picker("Active Track Cache", selection: bindingCacheLimit) {
                Text("64 MB").tag(Int64(64 * 1024 * 1024))
                Text("128 MB").tag(Int64(128 * 1024 * 1024))
                Text("256 MB").tag(Int64(256 * 1024 * 1024))
                Text("512 MB").tag(Int64(512 * 1024 * 1024))
            }
        }
        .padding()
    }

    private var bindingFormat: Binding<ResolvedStream.Format> {
        Binding(
            get: { appState?.preferredFormat ?? .mp3 },
            set: { appState?.preferredFormat = $0 }
        )
    }

    private var bindingCacheLimit: Binding<Int64> {
        Binding(
            get: { appState?.cacheLimitBytes ?? 256 * 1024 * 1024 },
            set: { appState?.cacheLimitBytes = $0 }
        )
    }
}
```

- [ ] **Step 2: Add local library placeholder views with real data hooks**

Create `Sources/KHPlayer/Features/Library/LocalLibraryViews.swift`:

```swift
import SwiftUI

struct HistoryView: View {
    @Environment(\.appState) private var appState
    @State private var entries: [HistoryEntry] = []

    var body: some View {
        List(entries, id: \.trackID) { entry in
            VStack(alignment: .leading) {
                Text(entry.title)
                Text(entry.playedAt.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            entries = (try? appState?.store.recentHistory(limit: 100)) ?? []
        }
    }
}

struct FavoritesView: View {
    var body: some View {
        ContentUnavailableView("Favorites", systemImage: "heart", description: Text("Favorite albums and tracks will appear here."))
    }
}
```

- [ ] **Step 3: Add sidebar enum**

Create or replace `Sources/KHPlayer/Features/Shell/SidebarView.swift`:

```swift
import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable {
    case search
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "Search"
        case .favorites: return "Favorites"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .search: return "magnifyingglass"
        case .favorites: return "heart"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }
}
```

- [ ] **Step 4: Wire destinations**

Modify `ContentView` to use `@State private var destination: SidebarDestination = .search` and render `SettingsView`, `HistoryView`, or `FavoritesView` when selected.

- [ ] **Step 5: Compile**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/KHPlayer/Features/Settings Sources/KHPlayer/Features/Library Sources/KHPlayer/Features/Shell
git commit -m "feat: add settings and local library views"
```

### Task 16: Add Safety, Rate Limiting, And Final Verification

**Files:**
- Modify: `Sources/KHPlayer/Networking/KHClient.swift`
- Modify: `README.md`

- [ ] **Step 1: Add request spacing to KHClient**

Modify `KHClient` to serialize HTML requests with a minimum 500 ms gap:

```swift
actor RequestGate {
    private var lastRequestDate = Date.distantPast
    private let minimumGap: TimeInterval

    init(minimumGap: TimeInterval) {
        self.minimumGap = minimumGap
    }

    func waitTurn() async {
        let now = Date()
        let nextAllowed = lastRequestDate.addingTimeInterval(minimumGap)
        if nextAllowed > now {
            let delay = nextAllowed.timeIntervalSince(now)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestDate = Date()
    }
}
```

Add `private let requestGate = RequestGate(minimumGap: 0.5)` to `KHClient`, and call `await requestGate.waitTurn()` before `session.data(for:)`.

- [ ] **Step 2: Add README usage notes**

Extend `README.md`:

```markdown
## Network Behavior

The app requests KHInsider pages only in response to user actions. It does not crawl the full catalog and does not prefetch full albums.

## Cache Behavior

Only the currently playing track is cached. Starting a different track clears the previous active-track cache. The default cache limit is 256 MB.
```

- [ ] **Step 3: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 4: Run app smoke test**

Run:

```bash
swift run KHPlayer
```

Expected:

- App launches.
- Search view is visible.
- Searching "persona" either returns album results or shows a Cloudflare/network message.
- Album detail opens from a result when network allows the request.
- Playing a track starts `AVPlayer` and creates files only inside `ActiveTrackCache`.
- Starting a second track clears the first track cache.

- [ ] **Step 5: Commit**

```bash
git add Sources/KHPlayer/Networking/KHClient.swift README.md
git commit -m "chore: document network and cache safety"
```

## Acceptance Criteria

- `swift test` passes.
- `swift run KHPlayer` opens a native macOS window.
- Search uses `/search?search=<query>&type=album&sort=relevance`.
- Album details are parsed from HTML, not rendered through WebView.
- Track playback resolves the media URL from the track detail page.
- Playback uses `AVPlayer`.
- Only the current track is cached.
- Current track cache honors the selected byte limit.
- Starting a new track clears previous active track cache files.
- Favorites and history are local.
- The app never calls KHInsider account endpoints.

## Known Follow-Up Work

- Add `.app` bundle packaging after the SwiftPM app is stable.
- Add artwork disk cache with a separate small limit.
- Add richer browse pages for alphabet, platform, year, top 40, and newly added.
- Add local playlist editing UI.
- Add keyboard shortcuts and menu commands.
- Add progress slider and duration observation in the mini player.
- Add stronger integration tests around `AVAssetResourceLoaderDelegate` with a local HTTP range server.

## Self-Review

- Spec coverage: the plan covers native macOS UI, HTML parsing, stream resolution, bounded current-track cache, local-only personal data, and streaming-only playback.
- Placeholder scan: no implementation task depends on undefined future work.
- Type consistency: `AlbumSummary`, `AlbumDetail`, `Track`, `ResolvedStream`, `PlaybackItem`, `PlaybackQueue`, `ActiveTrackCache`, and `LibraryStore` names match across tasks.
- Scope check: packaging, richer browse views, artwork cache, and advanced mini-player controls are intentionally follow-up work because the MVP remains search-to-album-to-stream playback.
