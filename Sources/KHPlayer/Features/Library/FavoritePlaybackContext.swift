import Foundation

internal enum FavoritePlaybackContext {
    internal static func playbackItems(from entries: [FavoriteTrackEntry]) -> [PlaybackItem] {
        entries.enumerated().compactMap { offset, entry in
            guard let albumURL = entry.albumURL, let detailURL = entry.detailURL else {
                return nil
            }

            let track = Track(
                id: entry.id,
                albumID: entry.albumID,
                discNumber: nil,
                number: offset + 1,
                title: entry.title,
                detailURL: detailURL,
                duration: entry.duration,
                mp3Size: nil
            )
            let album = AlbumDetail(
                id: entry.albumID,
                title: entry.albumTitle,
                url: albumURL,
                alternativeTitles: [],
                platforms: [],
                year: nil,
                publisher: nil,
                albumType: nil,
                fileCount: nil,
                totalDuration: nil,
                totalMP3Size: nil,
                dateAdded: nil,
                artworkURL: entry.artworkURL,
                description: nil,
                tracks: [track]
            )

            return PlaybackItem(
                id: entry.id,
                album: album,
                track: track
            )
        }
    }

    internal static func startingItem(
        in items: [PlaybackItem],
        selectedTrackID: String
    ) -> PlaybackItem? {
        items.first { item in
            item.track.id == selectedTrackID
        }
    }
}
