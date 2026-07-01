import Foundation

@main
struct AlbumParserBehaviorChecks {
    static func main() throws {
        try checkTrackRowsUseTrackNumberColumnAndUniqueIDs()
        try checkTrackRowsCaptureDiscNumberColumn()
    }

    private static func checkTrackRowsUseTrackNumberColumnAndUniqueIDs() throws {
        let html = """
        <html>
        <body>
        <h2>Persona 1 - The Complete Soundtrack</h2>
        <table id="songlist">
            <tr id="songlist_header">
                <th>&nbsp;</th>
                <th>CD</th>
                <th>#</th>
                <th colspan="2">Song Name</th>
                <th>MP3</th>
                <th>&nbsp;</th>
                <th>&nbsp;</th>
            </tr>
            <tr>
                <td align="center" title="play track"></td>
                <td align="center">1</td>
                <td align="right">1.</td>
                <td class="clickable-row"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-001.%2520Opening.mp3">Opening</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-001.%2520Opening.mp3">2:22</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-001.%2520Opening.mp3">7.27 MB</a></td>
                <td class="playlistDownloadSong"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-001.%2520Opening.mp3">get_app</a></td>
                <td class="playlistAddCell"></td>
            </tr>
            <tr>
                <td align="center" title="play track"></td>
                <td align="center">1</td>
                <td align="right">2.</td>
                <td class="clickable-row"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-002.%2520Daydream%25201.mp3">Daydream 1</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-002.%2520Daydream%25201.mp3">0:36</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-002.%2520Daydream%25201.mp3">3.24 MB</a></td>
                <td class="playlistDownloadSong"><a href="/game-soundtracks/album/persona-1-the-complete-soundtrack/1-002.%2520Daydream%25201.mp3">get_app</a></td>
                <td class="playlistAddCell"></td>
            </tr>
        </table>
        </body>
        </html>
        """

        let url = URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-1-the-complete-soundtrack")!
        let album = try AlbumPageParser.parse(html: html, url: url)

        precondition(album.tracks.count == 2)
        precondition(album.tracks.map(\.number) == [1, 2])
        precondition(album.tracks.map(\.title) == ["Opening", "Daydream 1"])
        precondition(Set(album.tracks.map(\.id)).count == album.tracks.count)
    }

    private static func checkTrackRowsCaptureDiscNumberColumn() throws {
        let html = """
        <html>
        <body>
        <h2>Persona 3 Portable Original Soundtrack</h2>
        <table id="songlist">
            <tr id="songlist_header">
                <th>&nbsp;</th>
                <th>CD</th>
                <th>#</th>
                <th colspan="2">Song Name</th>
                <th>MP3</th>
                <th>Extra</th>
            </tr>
            <tr>
                <td align="center" title="play track"></td>
                <td align="center">1</td>
                <td align="right">37.</td>
                <td class="clickable-row"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/1-037.%2520Living%2520With%2520Determination.mp3">Living With Determination</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/1-037.%2520Living%2520With%2520Determination.mp3">3:05</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/1-037.%2520Living%2520With%2520Determination.mp3">5.27 MB</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/1-037.%2520Living%2520With%2520Determination.mp3">13.63 MB</a></td>
            </tr>
            <tr>
                <td align="center" title="play track"></td>
                <td align="center">2</td>
                <td align="right">1.</td>
                <td class="clickable-row"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/2-001.%2520tartarus_0d04.mp3">tartarus_0d04</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/2-001.%2520tartarus_0d04.mp3">3:34</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/2-001.%2520tartarus_0d04.mp3">6.72 MB</a></td>
                <td class="clickable-row" align="right"><a href="/game-soundtracks/album/persona-3-portable-original-soundtrack-2025/2-001.%2520tartarus_0d04.mp3">22.60 MB</a></td>
            </tr>
        </table>
        </body>
        </html>
        """

        let url = URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-3-portable-original-soundtrack-2025")!
        let album = try AlbumPageParser.parse(html: html, url: url)

        precondition(album.tracks.map(\.discNumber) == [1, 2])
        precondition(album.tracks.map(\.number) == [37, 1])
    }
}
