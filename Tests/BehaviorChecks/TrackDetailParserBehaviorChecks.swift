import Foundation

@main
struct TrackDetailParserBehaviorChecks {
    static func main() throws {
        try checkNonASCIIStreamURLPreservesEncodedSpaces()
    }

    private static func checkNonASCIIStreamURLPreservesEncodedSpaces() throws {
        let html = """
        <p>
          <a href="https://nu.vgmtreasurechest.com/soundtracks/pok\u{00e9}mon-legends-za-switch-switch-2-gamerip-2025/ggccjrfgmq/1-01.%20Disturbance%20at%20Prism%20Tower.mp3">
            <span class="songDownloadLink">Click here to download as MP3</span>
          </a> (1.32 MB)
        </p>
        """

        let streams = try TrackDetailParser.parse(html: html, trackID: "pokemon-za-1")

        precondition(streams.count == 1)
        precondition(
            streams[0].sourceURL.absoluteString ==
            "https://nu.vgmtreasurechest.com/soundtracks/pok%C3%A9mon-legends-za-switch-switch-2-gamerip-2025/ggccjrfgmq/1-01.%20Disturbance%20at%20Prism%20Tower.mp3"
        )
    }
}
