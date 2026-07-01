import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. This helper documents the
// intended AlbumPageParser fixture checks without importing a test framework.
internal struct AlbumPageParserTests {
    internal func personaVinylFixtureParsesAlbumDetail() throws {
        guard let fixtureURL = Bundle.module.url(
            forResource: "PersonaVinylAlbum",
            withExtension: "html"
        ) else {
            preconditionFailure("Expected PersonaVinylAlbum.html fixture.")
        }

        let html = try String(contentsOf: fixtureURL, encoding: .utf8)
        let url = URL(string: "https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022")!
        let album = try AlbumPageParser.parse(html: html, url: url)

        precondition(album.id == "persona-vinyl-soundtrack-2022")
        precondition(album.title == "Persona Vinyl Soundtrack")
        precondition(album.alternativeTitles == [
            "SMT Persona 1 Vinyl Soundtrack",
            "Persona 1 Vinyl Soundtrack"
        ])
        precondition(album.platforms == ["PS1", "Windows"])
        precondition(album.year == 2022)
        precondition(album.publisher == "iam8bit")
        precondition(album.albumType == "Soundtrack")
        precondition(album.fileCount == 23)
        precondition(album.totalMP3Size == "87 MB")
        precondition(album.dateAdded == "May 29th, 2024")
        precondition(album.artworkURL?.absoluteString == "https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/folder.png")
        precondition(album.description == "Vinyl rip of Iam8bit's release.")
        precondition(album.tracks.count == 1)

        let track = album.tracks[0]
        precondition(track.id == "persona-vinyl-soundtrack-2022-1-01.-Persona.mp3")
        precondition(track.albumID == "persona-vinyl-soundtrack-2022")
        precondition(track.number == 1)
        precondition(track.title == "Persona")
        precondition(track.detailURL.absoluteString == "https://downloads.khinsider.com/game-soundtracks/album/persona-vinyl-soundtrack-2022/01.%2520Persona.mp3")
        precondition(track.duration == 186)
        precondition(track.mp3Size == "5.43 MB")
    }
}
