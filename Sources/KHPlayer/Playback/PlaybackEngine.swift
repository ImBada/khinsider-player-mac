import AVFoundation
import Combine
import Foundation

@MainActor
internal final class PlaybackEngine: ObservableObject {
    private struct PrefetchedTrack {
        let trackID: String
        let localURL: URL

        func matches(_ item: PlaybackItem) -> Bool {
            trackID == item.track.id
        }
    }

    @Published internal private(set) var currentItem: PlaybackItem?
    @Published internal private(set) var isPlaying = false
    @Published internal var volume: Float = 1 {
        didSet {
            player?.volume = volume
        }
    }
    @Published internal private(set) var elapsedTime: TimeInterval = 0
    @Published internal private(set) var duration: TimeInterval = 0

    @Published internal var repeatMode: RepeatMode = .off {
        didSet {
            queue.repeatMode = repeatMode
        }
    }

    @Published internal var isShuffleEnabled = false {
        didSet {
            queue.setShuffleEnabled(isShuffleEnabled)
            if currentItem != nil {
                startPrefetchForNextItem(after: playbackGeneration)
            }
        }
    }

    private let resolver: any StreamResolving
    private let cache: ActiveTrackCache
    private let resourceLoaderQueue = DispatchQueue(
        label: "com.khinsider-player.playback.resource-loader"
    )

    private var player: AVPlayer?
    private var resourceLoader: CachingStreamResourceLoader?
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var playerItemDurationObservation: NSKeyValueObservation?
    private var playerItemEndObserver: NSObjectProtocol?
    private var playerTimeObserver: Any?
    private var queue = PlaybackQueue<PlaybackItem>(items: [], currentIndex: 0)
    private var playbackGeneration = 0
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedTrack: PrefetchedTrack?
    private var localPlaybackFileURL: URL?
    private let prefetchDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("khinsider-player-next-prefetch-\(UUID().uuidString)", isDirectory: true)

    internal init(resolver: any StreamResolving, cache: ActiveTrackCache) {
        self.resolver = resolver
        self.cache = cache
    }

    internal func play(
        album: AlbumDetail,
        startingAt track: Track
    ) async throws {
        let playbackItems = album.tracks.map { albumTrack in
            PlaybackItem(
                id: albumTrack.id,
                album: album,
                track: albumTrack
            )
        }
        let startingItem = playbackItems.first { $0.track == track } ?? playbackItems.first

        guard let startingItem else {
            stop()
            return
        }

        try await play(items: playbackItems, startingAt: startingItem)
    }

    internal func play(
        items playbackItems: [PlaybackItem],
        startingAt item: PlaybackItem
    ) async throws {
        guard !playbackItems.isEmpty else {
            stop()
            return
        }

        let startingIndex = playbackItems.firstIndex { $0.id == item.id } ?? 0

        queue = PlaybackQueue(
            items: playbackItems,
            currentIndex: startingIndex,
            repeatMode: repeatMode,
            isShuffleEnabled: isShuffleEnabled
        )

        try await playCurrent()
    }

    internal func togglePlayPause() {
        guard let player else {
            isPlaying = false
            currentItem = nil
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    internal func next() async throws {
        guard queue.advance() != nil else {
            stop()
            return
        }

        try await playCurrent()
    }

    internal func seek(to seconds: TimeInterval) {
        guard let player else {
            return
        }

        let boundedSeconds = duration > 0 ? min(max(seconds, 0), duration) : max(seconds, 0)
        elapsedTime = boundedSeconds
        player.seek(
            to: CMTime(seconds: boundedSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }
}

extension PlaybackEngine {
    private func playCurrent() async throws {
        guard let item = queue.current else {
            stop()
            return
        }

        let generation = try beginPlaybackAttempt()
        currentItem = item
        elapsedTime = 0
        duration = item.track.duration ?? 0

        do {
            if try await playPrefetchedTrack(item, generation: generation) {
                startPrefetchForNextItem(after: generation)
                return
            }

            cancelPrefetch(deleteFile: true)

            let stream = try await resolver.resolve(track: item.track)
            try ensureCurrentPlayback(generation)
            try cache.prepareForTrack(cacheKey: stream.trackID)
            try ensureCurrentPlayback(generation)

            let loader = CachingStreamResourceLoader(
                sourceURL: stream.sourceURL,
                cache: cache,
                contentType: AVFileType.mp3.rawValue,
                contentLength: stream.contentLength
            )
            let asset = AVURLAsset(url: CachingStreamResourceLoader.assetURL(for: stream))
            asset.resourceLoader.setDelegate(loader, queue: resourceLoaderQueue)

            let playerItem = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.volume = volume
            try ensureCurrentPlayback(generation)

            resourceLoader = loader
            player = newPlayer
            currentItem = item
            elapsedTime = 0
            duration = item.track.duration ?? 0
            installObservers(for: playerItem, player: newPlayer, generation: generation)
            newPlayer.play()
            isPlaying = true
            startPrefetchForNextItem(after: generation)
        } catch {
            if isCurrentPlayback(generation) {
                cancelPlayback(clearCurrentItem: true)
            }

            throw error
        }
    }

    internal func stop() {
        playbackGeneration += 1
        cancelPrefetch(deleteFile: true)
        cancelPlayback(clearCurrentItem: true)
        try? cache.clear()
    }

    private func beginPlaybackAttempt() throws -> Int {
        playbackGeneration += 1
        cancelPrefetch(deleteFile: false)
        cancelPlayback(clearCurrentItem: true)
        try cache.clear()
        return playbackGeneration
    }

    private func ensureCurrentPlayback(_ generation: Int) throws {
        guard isCurrentPlayback(generation) else {
            throw CancellationError()
        }
    }

    private func isCurrentPlayback(_ generation: Int) -> Bool {
        playbackGeneration == generation
    }

    private func cancelPlayback(clearCurrentItem: Bool) {
        clearPlayerItemObservers()
        player?.pause()
        resourceLoader?.cancel()
        player = nil
        resourceLoader = nil
        isPlaying = false
        if let localPlaybackFileURL {
            try? FileManager.default.removeItem(at: localPlaybackFileURL)
            self.localPlaybackFileURL = nil
        }

        if clearCurrentItem {
            currentItem = nil
            elapsedTime = 0
            duration = 0
        }
    }

    private func playPrefetchedTrack(_ item: PlaybackItem, generation: Int) async throws -> Bool {
        try ensureCurrentPlayback(generation)
        guard let prefetchedTrack, prefetchedTrack.matches(item) else {
            return false
        }

        self.prefetchedTrack = nil

        let playerItem = AVPlayerItem(url: prefetchedTrack.localURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = volume
        try ensureCurrentPlayback(generation)

        localPlaybackFileURL = prefetchedTrack.localURL
        player = newPlayer
        currentItem = item
        elapsedTime = 0
        duration = item.track.duration ?? 0
        installObservers(for: playerItem, player: newPlayer, generation: generation)
        newPlayer.play()
        isPlaying = true
        return true
    }

    private func startPrefetchForNextItem(after generation: Int) {
        guard let nextItem = nextItemForPrefetch() else {
            cancelPrefetch(deleteFile: true)
            return
        }

        if prefetchedTrack?.matches(nextItem) == true {
            return
        }

        cancelPrefetch(deleteFile: true)

        let resolver = self.resolver
        let cacheLimitBytes = cache.maximumSizeBytes
        let prefetchDirectory = self.prefetchDirectory
        prefetchTask = Task { [weak self] in
            do {
                let stream = try await resolver.resolve(track: nextItem.track)

                if let contentLength = stream.contentLength, contentLength > cacheLimitBytes {
                    throw KHError.cacheLimitTooSmall
                }

                let localURL = try await Self.downloadPrefetchedTrack(
                    stream: stream,
                    directory: prefetchDirectory,
                    maximumSizeBytes: cacheLimitBytes
                )

                try Task.checkCancellation()

                await MainActor.run { [weak self] in
                    guard let self,
                          self.isCurrentPlayback(generation),
                          self.nextItemForPrefetch() == nextItem else {
                        try? FileManager.default.removeItem(at: localURL)
                        return
                    }

                    self.prefetchedTrack = PrefetchedTrack(
                        trackID: nextItem.track.id,
                        localURL: localURL
                    )
                    self.prefetchTask = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.isCurrentPlayback(generation) else {
                        return
                    }

                    self.prefetchTask = nil
                }
            }
        }
    }

    private func nextItemForPrefetch() -> PlaybackItem? {
        guard !queue.items.isEmpty else {
            return nil
        }

        if queue.repeatMode == .one {
            return queue.current
        }

        guard queue.items.indices.contains(queue.currentIndex) else {
            return nil
        }

        let nextIndex = queue.currentIndex + 1
        if queue.items.indices.contains(nextIndex) {
            return queue.items[nextIndex]
        }

        if queue.repeatMode == .all {
            return queue.items[queue.items.startIndex]
        }

        return nil
    }

    private func cancelPrefetch(deleteFile: Bool) {
        prefetchTask?.cancel()
        prefetchTask = nil

        if deleteFile, let prefetchedTrack {
            try? FileManager.default.removeItem(at: prefetchedTrack.localURL)
            self.prefetchedTrack = nil
        }
    }

    private func installObservers(for playerItem: AVPlayerItem, player: AVPlayer, generation: Int) {
        clearPlayerItemObservers()

        playerItemStatusObservation = playerItem.observe(\.status, options: [.new]) { [weak self, weak playerItem] observedItem, _ in
            guard observedItem.status == .failed else {
                return
            }

            Task { @MainActor [weak self, weak playerItem] in
                guard let self,
                      let playerItem,
                      self.isCurrentPlayback(generation),
                      self.player?.currentItem === playerItem else {
                    return
                }

                self.cancelPlayback(clearCurrentItem: true)
            }
        }

        playerItemDurationObservation = playerItem.observe(\.duration, options: [.initial, .new]) { [weak self, weak playerItem] observedItem, _ in
            Task { @MainActor [weak self, weak playerItem] in
                guard let self,
                      let playerItem,
                      self.isCurrentPlayback(generation),
                      self.player?.currentItem === playerItem else {
                    return
                }

                self.updateDuration(from: observedItem.duration)
            }
        }

        playerTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self, weak player] time in
            Task { @MainActor [weak self, weak player] in
                guard let self,
                      let player,
                      self.isCurrentPlayback(generation),
                      self.player === player else {
                    return
                }

                self.updateElapsedTime(from: time)
            }
        }

        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self, weak playerItem] _ in
            Task { @MainActor [weak self, weak playerItem] in
                guard let self,
                      let playerItem,
                      self.isCurrentPlayback(generation),
                      self.player?.currentItem === playerItem else {
                    return
                }

                self.elapsedTime = self.duration
                do {
                    try await self.next()
                } catch is CancellationError {
                    // A newer playback request superseded this automatic advance.
                } catch {
                    self.cancelPlayback(clearCurrentItem: true)
                }
            }
        }
    }

    private func clearPlayerItemObservers() {
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil

        playerItemDurationObservation?.invalidate()
        playerItemDurationObservation = nil

        if let playerTimeObserver {
            player?.removeTimeObserver(playerTimeObserver)
            self.playerTimeObserver = nil
        }

        if let playerItemEndObserver {
            NotificationCenter.default.removeObserver(playerItemEndObserver)
            self.playerItemEndObserver = nil
        }
    }

    private func updateElapsedTime(from time: CMTime) {
        guard time.isNumeric else {
            return
        }

        let seconds = max(time.seconds, 0)
        elapsedTime = duration > 0 ? min(seconds, duration) : seconds
    }

    private func updateDuration(from time: CMTime) {
        guard time.isNumeric else {
            return
        }

        duration = max(time.seconds, 0)
        elapsedTime = min(elapsedTime, duration)
    }

    nonisolated private static func downloadPrefetchedTrack(
        stream: ResolvedStream,
        directory: URL,
        maximumSizeBytes: Int64
    ) async throws -> URL {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let safeTrackID = Self.safePrefetchFileComponent(for: stream.trackID)
        let fileName = "\(safeTrackID)-\(UUID().uuidString).mp3"
        let finalURL = directory.appendingPathComponent(fileName)
        let temporaryURL = directory.appendingPathComponent("\(fileName).download")
        try? FileManager.default.removeItem(at: temporaryURL)

        _ = FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: temporaryURL)
        var shouldRemoveTemporaryFile = true

        defer {
            try? fileHandle.close()
            if shouldRemoveTemporaryFile {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }

        let (bytes, response) = try await URLSession.shared.bytes(from: stream.sourceURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw KHError.networkStatus(httpResponse.statusCode)
        }

        var downloadedBytes: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            try Task.checkCancellation()
            downloadedBytes += 1
            if downloadedBytes > maximumSizeBytes {
                throw KHError.cacheLimitTooSmall
            }

            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try fileHandle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
        }

        try fileHandle.close()

        if FileManager.default.fileExists(atPath: finalURL.path) {
            let replacedURL = try FileManager.default.replaceItemAt(
                finalURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: []
            ) ?? finalURL
            shouldRemoveTemporaryFile = false
            return replacedURL
        }

        try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
        shouldRemoveTemporaryFile = false
        return finalURL
    }

    nonisolated private static func safePrefetchFileComponent(for trackID: String) -> String {
        let allowedCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let sanitized = String(trackID.map { character in
            allowedCharacters.contains(character) ? character : "-"
        })
        return sanitized.isEmpty ? "track" : sanitized
    }
}
