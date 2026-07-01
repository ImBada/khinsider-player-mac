import Foundation

internal final class ActiveTrackCache {
    private struct StoredSegment {
        let range: Range<Int64>
        let fileOffset: Int

        var length: Int {
            Int(range.upperBound - range.lowerBound)
        }
    }

    private struct SegmentPayload {
        let range: Range<Int64>
        let data: Data
    }

    private struct Chunk {
        let start: Int64
        var segments: [StoredSegment]
        var lastAccess: UInt64

        var byteCount: Int64 {
            segments.reduce(Int64(0)) { $0 + Int64($1.length) }
        }

        func covers(_ requestedRange: Range<Int64>) -> Bool {
            var cursor = requestedRange.lowerBound
            let sortedSegments = segments.sorted { $0.range.lowerBound < $1.range.lowerBound }

            for segment in sortedSegments {
                guard segment.range.upperBound > cursor else {
                    continue
                }

                guard segment.range.lowerBound <= cursor else {
                    return false
                }

                cursor = min(max(cursor, segment.range.upperBound), requestedRange.upperBound)

                if cursor == requestedRange.upperBound {
                    return true
                }
            }

            return cursor == requestedRange.upperBound
        }
    }

    private let directory: URL
    private let limitBytes: Int64
    private let chunkSize: Int64
    private var chunks: [Int64: Chunk] = [:]
    private var accessCounter: UInt64 = 0

    internal init(
        directory: URL,
        limitBytes: Int64,
        chunkSize: Int64 = 512 * 1024
    ) throws {
        guard chunkSize > 0, chunkSize <= Int64(Int.max), limitBytes >= chunkSize else {
            throw KHError.cacheLimitTooSmall
        }

        self.directory = directory
        self.limitBytes = limitBytes
        self.chunkSize = chunkSize

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    internal func prepareForTrack(cacheKey: String) throws {
        // One active-track directory is used; avoid putting arbitrary cache keys in paths.
        _ = cacheKey

        try clear()
    }

    internal func clear() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        chunks.removeAll()
        accessCounter = 0
    }

    internal func store(data: Data, rangeStart: Int64) throws {
        guard rangeStart >= 0, !data.isEmpty else {
            return
        }

        var offset = 0
        var cursor = rangeStart

        while offset < data.count {
            let chunkStart = normalizedChunkStart(for: cursor)
            let chunkEnd = chunkStart + chunkSize
            let pieceLength = min(data.count - offset, Int(chunkEnd - cursor))
            let pieceRange = cursor..<(cursor + Int64(pieceLength))
            let pieceData = data.subdata(in: offset..<(offset + pieceLength))

            try store(pieceData: pieceData, range: pieceRange, chunkStart: chunkStart)

            offset += pieceLength
            cursor += Int64(pieceLength)
        }

        try enforceLimit()
    }

    internal func data(for range: Range<Int64>) throws -> Data? {
        guard range.lowerBound >= 0 else {
            return nil
        }

        if range.isEmpty {
            return Data()
        }

        var requestedChunks: [(start: Int64, range: Range<Int64>)] = []
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let chunkStart = normalizedChunkStart(for: cursor)
            let chunkEnd = min(chunkStart + chunkSize, range.upperBound)
            let requestedRange = cursor..<chunkEnd

            guard let chunk = chunks[chunkStart], chunk.covers(requestedRange) else {
                return nil
            }

            requestedChunks.append((chunkStart, requestedRange))
            cursor = chunkEnd
        }

        var result = Data()
        for requestedChunk in requestedChunks {
            guard let chunk = chunks[requestedChunk.start],
                  let payloads = try payloads(for: chunk),
                  appendPayloads(
                    payloads,
                    for: requestedChunk.range,
                    to: &result
                  ) else {
                try? FileManager.default.removeItem(at: chunkURL(start: requestedChunk.start))
                chunks.removeValue(forKey: requestedChunk.start)
                return nil
            }
        }

        let access = nextAccessValue()
        for requestedChunk in requestedChunks {
            chunks[requestedChunk.start]?.lastAccess = access
        }

        return result
    }

    internal func currentSize() throws -> Int64 {
        chunks.values.reduce(Int64(0)) { $0 + $1.byteCount }
    }

    internal var maximumSizeBytes: Int64 {
        limitBytes
    }

    private func store(
        pieceData: Data,
        range: Range<Int64>,
        chunkStart: Int64
    ) throws {
        let existingPayloads: [SegmentPayload]
        if let chunk = chunks[chunkStart],
           let payloads = try payloads(for: chunk) {
            existingPayloads = payloads
        } else {
            existingPayloads = []
        }

        let mergedPayloads = merge(
            existingPayloads + [SegmentPayload(range: range, data: pieceData)],
            chunkStart: chunkStart
        )

        try write(payloads: mergedPayloads, chunkStart: chunkStart)
    }

    private func merge(
        _ payloads: [SegmentPayload],
        chunkStart: Int64
    ) -> [SegmentPayload] {
        let chunkLength = Int(chunkSize)
        var bytes = Data(count: chunkLength)
        var covered = Array(repeating: false, count: chunkLength)

        for payload in payloads {
            let offset = Int(payload.range.lowerBound - chunkStart)
            let end = offset + payload.data.count

            guard offset >= 0, end <= chunkLength else {
                continue
            }

            bytes.replaceSubrange(offset..<end, with: payload.data)

            for index in offset..<end {
                covered[index] = true
            }
        }

        var merged: [SegmentPayload] = []
        var index = 0

        while index < chunkLength {
            while index < chunkLength, !covered[index] {
                index += 1
            }

            guard index < chunkLength else {
                break
            }

            let segmentStart = index
            while index < chunkLength, covered[index] {
                index += 1
            }

            let segmentEnd = index
            let range = (chunkStart + Int64(segmentStart))..<(chunkStart + Int64(segmentEnd))
            let data = bytes.subdata(in: segmentStart..<segmentEnd)
            merged.append(SegmentPayload(range: range, data: data))
        }

        return merged
    }

    private func write(payloads: [SegmentPayload], chunkStart: Int64) throws {
        var fileData = Data()
        var segments: [StoredSegment] = []

        for payload in payloads {
            segments.append(
                StoredSegment(
                    range: payload.range,
                    fileOffset: fileData.count
                )
            )
            fileData.append(payload.data)
        }

        try fileData.write(to: chunkURL(start: chunkStart), options: .atomic)
        chunks[chunkStart] = Chunk(
            start: chunkStart,
            segments: segments,
            lastAccess: nextAccessValue()
        )
    }

    private func payloads(for chunk: Chunk) throws -> [SegmentPayload]? {
        let url = chunkURL(start: chunk.start)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let fileData = try Data(contentsOf: url)
        var payloads: [SegmentPayload] = []

        for segment in chunk.segments.sorted(by: { $0.fileOffset < $1.fileOffset }) {
            let end = segment.fileOffset + segment.length
            guard segment.fileOffset >= 0, end <= fileData.count else {
                return nil
            }

            payloads.append(
                SegmentPayload(
                    range: segment.range,
                    data: fileData.subdata(in: segment.fileOffset..<end)
                )
            )
        }

        return payloads
    }

    private func appendPayloads(
        _ payloads: [SegmentPayload],
        for range: Range<Int64>,
        to result: inout Data
    ) -> Bool {
        var cursor = range.lowerBound
        let sortedPayloads = payloads.sorted { $0.range.lowerBound < $1.range.lowerBound }

        for payload in sortedPayloads {
            guard payload.range.upperBound > cursor else {
                continue
            }

            guard payload.range.lowerBound <= cursor else {
                return false
            }

            let start = max(cursor, payload.range.lowerBound)
            let end = min(range.upperBound, payload.range.upperBound)
            let offset = Int(start - payload.range.lowerBound)
            let length = Int(end - start)

            result.append(payload.data.subdata(in: offset..<(offset + length)))
            cursor = end

            if cursor == range.upperBound {
                return true
            }
        }

        return cursor == range.upperBound
    }

    private func enforceLimit() throws {
        while try currentSize() > limitBytes {
            guard let victim = chunks.values.min(by: {
                if $0.lastAccess == $1.lastAccess {
                    return $0.start < $1.start
                }

                return $0.lastAccess < $1.lastAccess
            }) else {
                return
            }

            try? FileManager.default.removeItem(at: chunkURL(start: victim.start))
            chunks.removeValue(forKey: victim.start)
        }
    }

    private func normalizedChunkStart(for position: Int64) -> Int64 {
        (position / chunkSize) * chunkSize
    }

    private func chunkURL(start: Int64) -> URL {
        directory.appending(path: "chunk-\(start).bin")
    }

    private func nextAccessValue() -> UInt64 {
        accessCounter += 1
        return accessCounter
    }
}
