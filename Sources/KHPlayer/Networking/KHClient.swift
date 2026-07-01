import Foundation

internal actor RequestGate {
    private let minimumDelay: Duration
    private let clock: ContinuousClock
    private var nextRequestTime: ContinuousClock.Instant?

    internal init(minimumDelay: Duration = .milliseconds(500)) {
        self.minimumDelay = minimumDelay
        self.clock = ContinuousClock()
    }

    internal func waitForTurn() async throws {
        try Task.checkCancellation()

        let now = clock.now
        guard let nextRequestTime, now < nextRequestTime else {
            self.nextRequestTime = now.advanced(by: minimumDelay)
            return
        }

        self.nextRequestTime = nextRequestTime.advanced(by: minimumDelay)
        try await clock.sleep(until: nextRequestTime, tolerance: nil)
        try Task.checkCancellation()
    }
}

internal final class KHClient: Sendable {
    private let session: URLSession
    private let requestGate: RequestGate

    internal init(session: URLSession = .shared) {
        self.session = session
        self.requestGate = RequestGate()
    }

    internal func html(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(
            "KHInsiderPlayerMac/0.1 (+https://downloads.khinsider.com/)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        try await requestGate.waitForTurn()
        try Task.checkCancellation()

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }

        switch httpResponse.statusCode {
        case 200..<300:
            if let html = String(data: data, encoding: .utf8) {
                return html
            }
            return String(decoding: data, as: UTF8.self)
        case 403:
            throw KHError.blockedByCloudflare
        default:
            throw KHError.networkStatus(httpResponse.statusCode)
        }
    }

    internal func streamMetadata(from url: URL) async throws -> StreamMetadata {
        do {
            return try await streamMetadata(from: url, httpMethod: "HEAD", rangeHeader: nil)
        } catch KHError.networkStatus(let status) where status == 405 || status == 501 {
            return try await streamMetadata(
                from: url,
                httpMethod: "GET",
                rangeHeader: "bytes=0-0"
            )
        }
    }

    private func streamMetadata(
        from url: URL,
        httpMethod: String,
        rangeHeader: String?
    ) async throws -> StreamMetadata {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue(
            "KHInsiderPlayerMac/0.1 (+https://downloads.khinsider.com/)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("audio/*,*/*", forHTTPHeaderField: "Accept")

        if let rangeHeader {
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }

        try await requestGate.waitForTurn()
        try Task.checkCancellation()

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return StreamMetadata(
                contentLength: contentLength(from: httpResponse),
                etag: header("ETag", in: httpResponse)
            )
        case 403:
            throw KHError.blockedByCloudflare
        default:
            throw KHError.networkStatus(httpResponse.statusCode)
        }
    }

    private func contentLength(from response: HTTPURLResponse) -> Int64? {
        if let contentRange = header("Content-Range", in: response),
           let totalLength = totalLength(fromContentRange: contentRange) {
            return totalLength
        }

        if response.expectedContentLength >= 0 {
            return response.expectedContentLength
        }

        return header("Content-Length", in: response).flatMap { value in
            Int64(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func totalLength(fromContentRange value: String) -> Int64? {
        guard let separator = value.lastIndex(of: "/") else {
            return nil
        }

        let total = value[value.index(after: separator)...]
        guard total != "*" else {
            return nil
        }

        return Int64(total.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func header(_ name: String, in response: HTTPURLResponse) -> String? {
        for (key, value) in response.allHeaderFields {
            guard String(describing: key).caseInsensitiveCompare(name) == .orderedSame else {
                continue
            }

            return String(describing: value)
        }

        return nil
    }
}

internal struct StreamMetadata: Equatable, Sendable {
    internal let contentLength: Int64?
    internal let etag: String?
}
