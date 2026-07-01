import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. This helper documents the
// intended TrackDetailParser fixture checks without importing a test framework.
internal struct TrackDetailParserTests {
    internal func personaTrackFixtureParsesMP3Stream() throws {
        guard let fixtureURL = Bundle.module.url(
            forResource: "PersonaTrackDetail",
            withExtension: "html"
        ) else {
            preconditionFailure("Expected PersonaTrackDetail.html fixture.")
        }

        let html = try String(contentsOf: fixtureURL, encoding: .utf8)
        let streams = try TrackDetailParser.parse(
            html: html,
            trackID: "persona-vinyl-soundtrack-2022-1"
        )

        precondition(streams.count == 1)

        precondition(streams[0].sourceURL.absoluteString == "https://nu.vgmtreasurechest.com/soundtracks/persona-vinyl-soundtrack-2022/kjtnjhjw/01.%20Persona.mp3")
        precondition(streams[0].sizeLabel == "5.43 MB")
    }

    internal func evilTreasureChestSuffixHostIsRejected() throws {
        let html = """
        <p>
          <a href="https://vgmtreasurechest.com.evil.test/fake.mp3">
            <span class="songDownloadLink">Click here to download as MP3</span>
          </a> (1.00 MB)
        </p>
        """
        let streams = try TrackDetailParser.parse(html: html, trackID: "fake-track")

        precondition(streams.isEmpty)
    }
}
