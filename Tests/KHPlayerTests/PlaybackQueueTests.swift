@testable import KHPlayer

// Compile-only placeholder for PlaybackQueue tests.
// XCTest and Swift Testing are not available in the local CommandLineTools setup.
internal struct PlaybackQueueTests {
    internal func queueAdvancesSequentiallyThenStopsAtEnd() {
        var queue = PlaybackQueue(items: ["a", "b", "c"], currentIndex: 0)

        precondition(queue.current == "a")
        precondition(queue.advance() == "b")
        precondition(queue.current == "b")
        precondition(queue.advance() == "c")
        precondition(queue.current == "c")
        precondition(queue.advance() == nil)
    }

    internal func repeatAllWrapsFromLastItemToFirstItem() {
        var queue = PlaybackQueue(
            items: ["a", "b"],
            currentIndex: 1,
            repeatMode: .all
        )

        precondition(queue.current == "b")
        precondition(queue.advance() == "a")
        precondition(queue.current == "a")
    }

    internal func repeatOneKeepsCurrentItem() {
        var queue = PlaybackQueue(
            items: ["a", "b"],
            currentIndex: 1,
            repeatMode: .one
        )

        precondition(queue.current == "b")
        precondition(queue.advance() == "b")
        precondition(queue.current == "b")
    }
}
