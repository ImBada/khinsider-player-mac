internal enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case one
    case all
}

internal struct PlaybackQueue<Item: Equatable> {
    internal var items: [Item]
    internal var currentIndex: Int
    internal var repeatMode: RepeatMode
    internal var isShuffleEnabled: Bool

    internal init(
        items: [Item],
        currentIndex: Int,
        repeatMode: RepeatMode = .off,
        isShuffleEnabled: Bool = false
    ) {
        self.items = items
        self.currentIndex = currentIndex
        self.repeatMode = repeatMode
        self.isShuffleEnabled = false
        setShuffleEnabled(isShuffleEnabled)
    }

    internal var current: Item? {
        guard items.indices.contains(currentIndex) else {
            return nil
        }

        return items[currentIndex]
    }

    @discardableResult
    internal mutating func advance() -> Item? {
        guard !items.isEmpty else {
            return nil
        }

        if repeatMode == .one {
            return current
        }

        guard items.indices.contains(currentIndex) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        if items.indices.contains(nextIndex) {
            currentIndex = nextIndex
            return items[currentIndex]
        }

        if repeatMode == .all {
            currentIndex = items.startIndex
            if isShuffleEnabled {
                shuffleUpcomingItems()
            }
            return items[currentIndex]
        }

        return nil
    }

    internal mutating func setShuffleEnabled(
        _ enabled: Bool,
        randomIndexInRange: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) {
        guard isShuffleEnabled != enabled else {
            return
        }

        isShuffleEnabled = enabled

        if enabled {
            shuffleUpcomingItems(randomIndexInRange: randomIndexInRange)
        }
    }

    private mutating func shuffleUpcomingItems(
        randomIndexInRange: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) {
        guard items.indices.contains(currentIndex) else {
            return
        }

        let firstUpcomingIndex = currentIndex + 1
        guard items.indices.contains(firstUpcomingIndex) else {
            return
        }

        for index in firstUpcomingIndex..<items.endIndex {
            let remainingRange = index..<items.endIndex
            let randomIndex = randomIndexInRange(remainingRange)
            precondition(remainingRange.contains(randomIndex))

            if randomIndex != index {
                items.swapAt(index, randomIndex)
            }
        }
    }
}
