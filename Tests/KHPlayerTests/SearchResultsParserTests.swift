import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. This helper documents the
// intended parser checks without importing a test framework.
internal struct SearchResultsParserTests {
    internal func personaFixtureParsesOneAlbumSummary() throws {
        guard let fixtureURL = Bundle.module.url(
            forResource: "SearchPersonaAlbums",
            withExtension: "html"
        ) else {
            preconditionFailure("Expected SearchPersonaAlbums.html fixture.")
        }

        let html = try String(contentsOf: fixtureURL, encoding: .utf8)
        let albums = try SearchResultsParser.parse(html: html)

        precondition(albums.count == 1)

        let album = albums[0]
        precondition(album.id == "persona-1-the-complete-soundtrack")
        precondition(album.title == "Persona 1 - The Complete Soundtrack")
        precondition(album.platforms == ["PS1", "PSP"])
        precondition(album.albumType == "Compilation")
        precondition(album.year == 1996)
        precondition(album.artworkURL?.host == "nu.vgmtreasurechest.com")
    }
}
