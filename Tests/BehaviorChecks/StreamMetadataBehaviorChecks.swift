import Foundation

@main
struct StreamMetadataBehaviorChecks {
    static func main() async throws {
        try await checkStreamMetadataUsesHeadAndCapturesLength()
        try checkStreamResolverAttachesMetadataToResolvedStreams()
    }

    private static func checkStreamMetadataUsesHeadAndCapturesLength() async throws {
        MetadataURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MetadataURLProtocol.self]
        let client = KHClient(session: URLSession(configuration: configuration))
        let url = URL(string: "https://nu.vgmtreasurechest.com/soundtracks/example/track.mp3")!

        let metadata = try await client.streamMetadata(from: url)

        precondition(MetadataURLProtocol.requests.map(\.httpMethod) == ["HEAD"])
        precondition(metadata.contentLength == 7_618_324)
        precondition(metadata.etag == #""647f85b2-743f14""#)
    }

    private static func checkStreamResolverAttachesMetadataToResolvedStreams() throws {
        let sourceURL = URL(fileURLWithPath: "Sources/KHPlayer/Playback/StreamResolver.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        precondition(source.contains("client.streamMetadata"))
        precondition(source.contains("contentLength: metadata.contentLength"))
        precondition(source.contains("etag: metadata.etag"))
    }
}

private final class MetadataURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    static func reset() {
        lock.lock()
        storedRequests.removeAll()
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.storedRequests.append(request)
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: [
                "Content-Length": "7618324",
                "ETag": #""647f85b2-743f14""#,
                "Accept-Ranges": "bytes"
            ]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
