#!/usr/bin/env bash
set -euo pipefail

swiftc \
  Sources/KHPlayer/Domain/KHError.swift \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Playback/ActiveTrackCache.swift \
  Sources/KHPlayer/Playback/CachingStreamResourceLoader.swift \
  Tests/BehaviorChecks/PlaybackCacheBehaviorChecks.swift \
  -o /tmp/khinsider-player-behavior-checks

/tmp/khinsider-player-behavior-checks

swiftc \
  Sources/KHPlayer/Playback/PlaybackQueue.swift \
  Tests/BehaviorChecks/PlaybackQueueBehaviorChecks.swift \
  -o /tmp/khinsider-player-playback-queue-checks

/tmp/khinsider-player-playback-queue-checks

BUILD_DIR="$(swift build --show-bin-path)"
swift build >/dev/null

swiftc \
  -I "$BUILD_DIR" \
  "$BUILD_DIR/SwiftSoup.o" \
  Sources/KHPlayer/Domain/KHError.swift \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Domain/HomeSectionModels.swift \
  Sources/KHPlayer/Networking/KHRequestBuilder.swift \
  Sources/KHPlayer/Parsing/HomeSectionParser.swift \
  Sources/KHPlayer/Persistence/HomeSectionsCache.swift \
  Tests/BehaviorChecks/HomeSectionsBehaviorChecks.swift \
  -o /tmp/khinsider-player-home-sections-checks

/tmp/khinsider-player-home-sections-checks

swiftc \
  -I "$BUILD_DIR" \
  "$BUILD_DIR/SwiftSoup.o" \
  Sources/KHPlayer/Domain/KHError.swift \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Parsing/AlbumPageParser.swift \
  Tests/BehaviorChecks/AlbumParserBehaviorChecks.swift \
  -o /tmp/khinsider-player-album-parser-checks

/tmp/khinsider-player-album-parser-checks

swiftc \
  Sources/KHPlayer/Domain/KHError.swift \
  Sources/KHPlayer/Networking/KHClient.swift \
  Tests/BehaviorChecks/StreamMetadataBehaviorChecks.swift \
  -o /tmp/khinsider-player-stream-metadata-checks

/tmp/khinsider-player-stream-metadata-checks

swiftc \
  Sources/KHPlayer/Domain/KHError.swift \
  Sources/KHPlayer/Persistence/ArtworkCache.swift \
  Tests/BehaviorChecks/LibraryStoreBehaviorChecks.swift \
  -o /tmp/khinsider-player-library-store-checks

/tmp/khinsider-player-library-store-checks

swiftc \
  -I "$BUILD_DIR" \
  -I .build/checkouts/GRDB.swift/Sources/GRDBSQLite \
  -Xcc -fmodule-map-file=.build/checkouts/GRDB.swift/Sources/GRDBSQLite/module.modulemap \
  "$BUILD_DIR/GRDB.o" \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Persistence/Records.swift \
  Sources/KHPlayer/Persistence/SchemaMigrator.swift \
  Sources/KHPlayer/Persistence/LibraryStore.swift \
  Tests/BehaviorChecks/FavoriteAlbumDetailCacheBehaviorChecks.swift \
  -o /tmp/khinsider-player-favorite-album-detail-cache-checks

/tmp/khinsider-player-favorite-album-detail-cache-checks

swiftc \
  -I "$BUILD_DIR" \
  -I .build/checkouts/GRDB.swift/Sources/GRDBSQLite \
  -Xcc -fmodule-map-file=.build/checkouts/GRDB.swift/Sources/GRDBSQLite/module.modulemap \
  "$BUILD_DIR/GRDB.o" \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Persistence/Records.swift \
  Sources/KHPlayer/Persistence/SchemaMigrator.swift \
  Sources/KHPlayer/Persistence/LibraryStore.swift \
  Sources/KHPlayer/Features/Library/FavoritePlaybackContext.swift \
  Tests/BehaviorChecks/FavoritePlaybackContextBehaviorChecks.swift \
  -o /tmp/khinsider-player-favorite-playback-context-checks

/tmp/khinsider-player-favorite-playback-context-checks

swiftc \
  -I "$BUILD_DIR" \
  -I .build/checkouts/GRDB.swift/Sources/GRDBSQLite \
  -Xcc -fmodule-map-file=.build/checkouts/GRDB.swift/Sources/GRDBSQLite/module.modulemap \
  "$BUILD_DIR/GRDB.o" \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Persistence/Records.swift \
  Sources/KHPlayer/Persistence/SchemaMigrator.swift \
  Sources/KHPlayer/Persistence/LibraryStore.swift \
  Sources/KHPlayer/Playback/PlaybackQueue.swift \
  Sources/KHPlayer/Features/Library/HistoryPlaybackContext.swift \
  Tests/BehaviorChecks/HistoryPlaybackContextBehaviorChecks.swift \
  -o /tmp/khinsider-player-history-playback-context-checks

/tmp/khinsider-player-history-playback-context-checks

swiftc \
  -I "$BUILD_DIR" \
  "$BUILD_DIR/SwiftSoup.o" \
  Sources/KHPlayer/Domain/KHError.swift \
  Sources/KHPlayer/Domain/Models.swift \
  Sources/KHPlayer/Networking/KHClient.swift \
  Sources/KHPlayer/Parsing/TrackDetailParser.swift \
  Sources/KHPlayer/Playback/ActiveTrackCache.swift \
  Sources/KHPlayer/Playback/CachingStreamResourceLoader.swift \
  Sources/KHPlayer/Playback/PlaybackQueue.swift \
  Sources/KHPlayer/Playback/StreamResolver.swift \
  Sources/KHPlayer/Playback/PlaybackEngine.swift \
  Tests/BehaviorChecks/PlaybackResponsivenessBehaviorChecks.swift \
  -o /tmp/khinsider-player-playback-responsiveness-checks

/tmp/khinsider-player-playback-responsiveness-checks

swiftc \
  -parse-as-library \
  Tests/BehaviorChecks/DesignBehaviorChecks.swift \
  -o /tmp/khinsider-player-design-checks

/tmp/khinsider-player-design-checks
