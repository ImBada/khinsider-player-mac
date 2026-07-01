import AVFoundation
import Foundation

internal final class CachingStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    private struct LoadingTask {
        let state: LoadingRequestState
        let task: Task<Void, Never>
    }

    private final class LoadingRequestState: @unchecked Sendable {
        let loadingRequest: AVAssetResourceLoadingRequest

        private let lock = NSLock()
        private var finished = false
        private var cancelled = false

        init(loadingRequest: AVAssetResourceLoadingRequest) {
            self.loadingRequest = loadingRequest
        }

        var isFinished: Bool {
            lock.lock()
            defer { lock.unlock() }
            return finished
        }

        func checkCancellation() throws {
            lock.lock()
            let isCancelled = cancelled
            lock.unlock()

            if isCancelled {
                throw CancellationError()
            }

            try Task.checkCancellation()
        }

        func finish() {
            lock.lock()
            guard !finished, !cancelled else {
                lock.unlock()
                return
            }

            finished = true
            lock.unlock()

            loadingRequest.finishLoading()
        }

        func finish(with error: Error) {
            lock.lock()
            guard !finished, !cancelled else {
                lock.unlock()
                return
            }

            finished = true
            lock.unlock()

            loadingRequest.finishLoading(with: error)
        }

        func cancel() {
            lock.lock()
            cancelled = true
            guard !finished else {
                lock.unlock()
                return
            }

            finished = true
            lock.unlock()

            loadingRequest.finishLoading()
        }
    }

    private let sourceURL: URL
    private let cache: ActiveTrackCache
    private let session: URLSession
    private let contentTypeIdentifier: String
    private let contentLength: Int64?

    private let lifecycleLock = NSLock()
    private let cacheLock = NSLock()
    private let loadingTasksLock = NSLock()
    private var isCancelled = false
    private var loadingTasks: [ObjectIdentifier: LoadingTask] = [:]

    internal init(
        sourceURL: URL,
        cache: ActiveTrackCache,
        session: URLSession = .shared,
        contentType: String = AVFileType.mp3.rawValue,
        contentLength: Int64? = nil
    ) {
        self.sourceURL = sourceURL
        self.cache = cache
        self.session = session
        self.contentTypeIdentifier = contentType
        self.contentLength = contentLength
    }

    internal func cancel() {
        lifecycleLock.lock()
        isCancelled = true
        lifecycleLock.unlock()

        let loadingTasks = removeAllLoadingTasks()
        for loadingTask in loadingTasks {
            loadingTask.task.cancel()
            loadingTask.state.cancel()
        }

        cacheLock.lock()
        cacheLock.unlock()
    }

    internal static func assetURL(for stream: ResolvedStream) -> URL {
        var components = URLComponents()
        components.scheme = "khcache"
        components.host = "track"
        components.path = "/" + stream.trackID

        if let url = components.url {
            return url
        }

        let encodedTrackID = stream.trackID.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? "track"
        let fallbackString = "khcache://track/\(encodedTrackID)"
        return URL(string: fallbackString) ?? URL(fileURLWithPath: "/khcache-invalid")
    }

    internal static func acceptsRangedResponse(statusCode: Int) -> Bool {
        statusCode == 206
    }
}

extension CachingStreamResourceLoader {
    internal func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard !isCancellationRequested else {
            loadingRequest.finishLoading()
            return false
        }

        let requestID = ObjectIdentifier(loadingRequest)
        let state = LoadingRequestState(loadingRequest: loadingRequest)
        let task = Task { [weak self, state] in
            guard let self else {
                state.cancel()
                return
            }

            do {
                try await self.handle(state)
            } catch is CancellationError {
                state.cancel()
            } catch {
                state.finish(with: error)
            }

            self.removeLoadingTask(for: requestID)
        }

        storeLoadingTask(LoadingTask(state: state, task: task), for: requestID)

        if state.isFinished {
            removeLoadingTask(for: requestID)
        }

        return true
    }

    internal func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let requestID = ObjectIdentifier(loadingRequest)
        guard let loadingTask = removeLoadingTask(for: requestID) else {
            loadingRequest.finishLoading()
            return
        }

        loadingTask.task.cancel()
        loadingTask.state.cancel()
    }
}

private extension CachingStreamResourceLoader {
    private func handle(_ state: LoadingRequestState) async throws {
        try checkCancellation()
        try state.checkCancellation()

        let loadingRequest = state.loadingRequest
        if let contentInformationRequest = loadingRequest.contentInformationRequest {
            contentInformationRequest.contentType = contentTypeIdentifier
            contentInformationRequest.isByteRangeAccessSupported = true

            if let contentLength {
                contentInformationRequest.contentLength = contentLength
            }
        }

        guard let dataRequest = loadingRequest.dataRequest else {
            state.finish()
            return
        }

        guard let requestedRange = requestedRange(for: dataRequest) else {
            state.finish()
            return
        }

        if let cachedData = try cachedData(for: requestedRange) {
            try state.checkCancellation()
            dataRequest.respond(with: cachedData)
            state.finish()
            return
        }

        let fetchedData = try await fetchRange(
            start: requestedRange.lowerBound,
            endExclusive: requestedRange.upperBound
        )
        try checkCancellation()
        try state.checkCancellation()

        try store(data: fetchedData, rangeStart: requestedRange.lowerBound)
        try state.checkCancellation()

        dataRequest.respond(with: fetchedData)
        state.finish()
    }

    private func requestedRange(for dataRequest: AVAssetResourceLoadingDataRequest) -> Range<Int64>? {
        guard dataRequest.requestedLength > 0 else {
            return nil
        }

        let requestedStart = dataRequest.requestedOffset
        let requestedLength = Int64(dataRequest.requestedLength)
        let (requestedEnd, overflow) = requestedStart.addingReportingOverflow(requestedLength)
        guard !overflow else {
            return nil
        }

        let start = dataRequest.currentOffset == requestedStart
            ? requestedStart
            : dataRequest.currentOffset

        guard start >= 0, requestedEnd > start else {
            return nil
        }

        return start..<requestedEnd
    }

    private var isCancellationRequested: Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isCancelled
    }

    private func checkCancellation() throws {
        if isCancellationRequested {
            throw CancellationError()
        }
    }

    private func cachedData(for range: Range<Int64>) throws -> Data? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        try checkCancellation()
        return try cache.data(for: range)
    }

    private func store(data: Data, rangeStart: Int64) throws {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        try checkCancellation()
        try cache.store(data: data, rangeStart: rangeStart)
    }

    private func fetchRange(start: Int64, endExclusive: Int64) async throws -> Data {
        var request = URLRequest(url: sourceURL)
        request.setValue("bytes=\(start)-\(endExclusive - 1)", forHTTPHeaderField: "Range")

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }

        guard Self.acceptsRangedResponse(statusCode: httpResponse.statusCode) else {
            throw KHError.networkStatus(httpResponse.statusCode)
        }

        return try await data(from: bytes, requestedLength: endExclusive - start)
    }

    private func data(
        from bytes: URLSession.AsyncBytes,
        requestedLength: Int64
    ) async throws -> Data {
        let byteCount = Int(clamping: requestedLength)
        guard byteCount > 0 else {
            return Data()
        }

        var data = Data()
        data.reserveCapacity(byteCount)

        var iterator = bytes.makeAsyncIterator()
        while data.count < byteCount {
            try checkCancellation()
            guard let byte = try await iterator.next() else {
                break
            }

            data.append(byte)
        }

        return data
    }

    private func storeLoadingTask(_ loadingTask: LoadingTask, for requestID: ObjectIdentifier) {
        loadingTasksLock.lock()
        loadingTasks[requestID] = loadingTask
        loadingTasksLock.unlock()
    }

    private func removeAllLoadingTasks() -> [LoadingTask] {
        loadingTasksLock.lock()
        defer { loadingTasksLock.unlock() }

        let tasks = Array(loadingTasks.values)
        loadingTasks.removeAll()
        return tasks
    }

    @discardableResult
    private func removeLoadingTask(for requestID: ObjectIdentifier) -> LoadingTask? {
        loadingTasksLock.lock()
        defer { loadingTasksLock.unlock() }
        return loadingTasks.removeValue(forKey: requestID)
    }
}
