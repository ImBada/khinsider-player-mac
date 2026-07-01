@main
struct PlaybackQueueBehaviorChecks {
    static func main() {
        checkShuffleKeepsCurrentTrackAndRandomizesUpcomingTracks()
    }

    private static func checkShuffleKeepsCurrentTrackAndRandomizesUpcomingTracks() {
        var queue = PlaybackQueue(items: ["a", "b", "c", "d"], currentIndex: 0)

        queue.setShuffleEnabled(true) { range in
            range.upperBound - 1
        }

        precondition(queue.current == "a")
        precondition(queue.advance() == "d")
        precondition(queue.advance() == "b")
        precondition(queue.advance() == "c")
        precondition(queue.advance() == nil)
    }
}
