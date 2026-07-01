import Foundation

internal protocol StreamResolving: Sendable {
    func resolve(track: Track) async throws -> ResolvedStream
}

internal final class StreamResolver: StreamResolving, Sendable {
    private let client: KHClient

    internal init(client: KHClient) {
        self.client = client
    }

    internal func resolve(track: Track) async throws -> ResolvedStream {
        let html = try await client.html(from: track.detailURL)
        let streams = try TrackDetailParser.parse(html: html, trackID: track.id)

        guard let stream = streams.first else {
            throw KHError.streamNotFound(trackTitle: track.title)
        }

        let metadata = try await client.streamMetadata(from: stream.sourceURL)
        return ResolvedStream(
            trackID: stream.trackID,
            sourceURL: stream.sourceURL,
            sizeLabel: stream.sizeLabel,
            contentLength: metadata.contentLength,
            etag: metadata.etag
        )
    }
}
