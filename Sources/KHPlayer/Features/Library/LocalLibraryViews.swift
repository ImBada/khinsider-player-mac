import AppKit
import Combine
import SwiftUI

internal struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    private let onPlayTrack: (HistoryEntry, [HistoryEntry]) -> Void

    private var _entries = State<[HistoryEntry]>(initialValue: [])
    private var _hoveredHistoryTrackID = State<String?>(initialValue: nil)
    private var _selectedHistoryTrackID = State<String?>(initialValue: nil)
    private var _currentPlaybackTrackID = State<String?>(initialValue: nil)
    private var _historySearchText = State<String>(initialValue: "")
    private var _isLoading = State<Bool>(initialValue: true)
    private var _errorMessage = State<String?>(initialValue: nil)

    internal init(
        onPlayTrack: @escaping (HistoryEntry, [HistoryEntry]) -> Void = { _, _ in }
    ) {
        self.onPlayTrack = onPlayTrack
    }

    internal var body: some View {
        VStack(spacing: 0) {
            MusicListHeader(
                title: "History",
                countLabel: historyCountLabel,
                searchText: historySearchTextBinding
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("History")
        .task {
            loadHistory()
        }
        .onReceive(currentPlaybackTrackIDPublisher) { trackID in
            currentPlaybackTrackID = trackID
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && entries.isEmpty {
            loadingState
        } else if let errorMessage {
            errorState(message: errorMessage)
        } else if entries.isEmpty {
            emptyState
        } else {
            historyList
        }
    }

    private var historyList: some View {
        HistorySongsTable(
            entries: filteredEntries,
            hoveredTrackID: hoveredHistoryTrackID,
            selectedTrackID: selectedHistoryTrackIDBinding,
            currentPlaybackTrackID: currentPlaybackTrackID,
            onHoverTrackChanged: { entry, isHovered in
                updateHistoryTrackHover(for: entry, isHovered: isHovered)
            },
            onPlayTrack: { entry in
                onPlayTrack(entry, filteredEntries)
            }
        )
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("Loading History")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No History",
            systemImage: "clock",
            description: Text("Tracks played on this Mac will appear here.")
        )
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("History Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                loadHistory()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
        }
        .textSelection(.enabled)
    }

    private var entries: [HistoryEntry] {
        get {
            _entries.wrappedValue
        }
        nonmutating set {
            _entries.wrappedValue = newValue
        }
    }

    private var hoveredHistoryTrackID: String? {
        get {
            _hoveredHistoryTrackID.wrappedValue
        }
        nonmutating set {
            _hoveredHistoryTrackID.wrappedValue = newValue
        }
    }

    private var selectedHistoryTrackIDBinding: Binding<String?> {
        _selectedHistoryTrackID.projectedValue
    }

    private var currentPlaybackTrackID: String? {
        get {
            _currentPlaybackTrackID.wrappedValue
        }
        nonmutating set {
            _currentPlaybackTrackID.wrappedValue = newValue
        }
    }

    private var currentPlaybackTrackIDPublisher: AnyPublisher<String?, Never> {
        appState.playbackEngine.$currentItem
            .map { item in item?.track.id }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private var historySearchText: String {
        get {
            _historySearchText.wrappedValue
        }
        nonmutating set {
            _historySearchText.wrappedValue = newValue
        }
    }

    private var historySearchTextBinding: Binding<String> {
        _historySearchText.projectedValue
    }

    private var filteredEntries: [HistoryEntry] {
        let query = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            entry.title.localizedStandardContains(query)
                || entry.albumID.localizedStandardContains(query)
                || (entry.albumTitle?.localizedStandardContains(query) ?? false)
        }
    }

    private var historyCountLabel: String {
        if filteredEntries.count == entries.count {
            return "\(entries.count) songs"
        }

        return "\(filteredEntries.count) of \(entries.count) songs"
    }

    private var isLoading: Bool {
        get {
            _isLoading.wrappedValue
        }
        nonmutating set {
            _isLoading.wrappedValue = newValue
        }
    }

    private var errorMessage: String? {
        get {
            _errorMessage.wrappedValue
        }
        nonmutating set {
            _errorMessage.wrappedValue = newValue
        }
    }

    private func loadHistory() {
        isLoading = true
        errorMessage = nil

        do {
            entries = try appState.libraryStore.recentHistory(limit: 100)
            hoveredHistoryTrackID = nil
            _selectedHistoryTrackID.wrappedValue = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func updateHistoryTrackHover(for entry: HistoryEntry, isHovered: Bool) {
        if isHovered {
            hoveredHistoryTrackID = entry.id
        } else if hoveredHistoryTrackID == entry.id {
            withAnimation(.easeOut(duration: FavoriteListLayout.hoverFadeDuration)) {
                hoveredHistoryTrackID = nil
            }
        }
    }
}

internal enum FavoriteCategory: String, CaseIterable, Identifiable {
    case albums = "Albums"
    case songs = "Songs"

    internal var id: Self {
        self
    }
}

internal struct FavoritesView: View {
    @EnvironmentObject private var appState: AppState

    private let category: FavoriteCategory
    private let onOpenAlbum: (AlbumSummary) -> Void
    private let onPlayTrack: (FavoriteTrackEntry, [FavoriteTrackEntry]) -> Void

    private var _albums = State<[FavoriteAlbumEntry]>(initialValue: [])
    private var _tracks = State<[FavoriteTrackEntry]>(initialValue: [])
    private var _hoveredFavoriteAlbumID = State<String?>(initialValue: nil)
    private var _hoveredFavoriteTrackID = State<String?>(initialValue: nil)
    private var _selectedFavoriteTrackID = State<String?>(initialValue: nil)
    private var _currentPlaybackTrackID = State<String?>(initialValue: nil)
    private var _favoriteSearchText = State<String>(initialValue: "")
    private var _isLoading = State<Bool>(initialValue: true)
    private var _errorMessage = State<String?>(initialValue: nil)

    internal init(
        onOpenAlbum: @escaping (AlbumSummary) -> Void = { _ in },
        category: FavoriteCategory = .albums,
        onPlayTrack: @escaping (FavoriteTrackEntry, [FavoriteTrackEntry]) -> Void = { _, _ in }
    ) {
        self.category = category
        self.onOpenAlbum = onOpenAlbum
        self.onPlayTrack = onPlayTrack
    }

    internal var body: some View {
        VStack(spacing: 0) {
            FavoritesHeader(
                category: category,
                albumCount: albums.count,
                trackCount: tracks.count,
                filteredTrackCount: filteredTracks.count,
                searchText: favoriteSearchTextBinding
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Favorites")
        .task {
            loadFavorites()
        }
        .onReceive(currentPlaybackTrackIDPublisher) { trackID in
            currentPlaybackTrackID = trackID
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && albums.isEmpty && tracks.isEmpty {
            loadingState
        } else if let errorMessage {
            errorState(message: errorMessage)
        } else {
            switch category {
            case .albums:
                albumContent
            case .songs:
                trackContent
            }
        }
    }

    @ViewBuilder
    private var albumContent: some View {
        if albums.isEmpty {
            ContentUnavailableView(
                "No Favorite Albums",
                systemImage: "star",
                description: Text("Albums added with the plus button will appear here.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(albums) { album in
                        FavoriteAlbumRow(
                            entry: album,
                            isHovered: hoveredFavoriteAlbumID == album.id,
                            onHoverChanged: { isHovered in
                                updateFavoriteAlbumHover(for: album, isHovered: isHovered)
                            }
                        ) {
                            open(album)
                        }

                        Divider()
                            .padding(.leading, FavoriteListLayout.albumSeparatorLeadingInset)
                    }
                }
                .padding(.horizontal, FavoriteListLayout.contentHorizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
        }
    }

    @ViewBuilder
    private var trackContent: some View {
        if tracks.isEmpty {
            ContentUnavailableView(
                "No Favorite Songs",
                systemImage: "star",
                description: Text("Songs starred from album track lists will appear here.")
            )
        } else {
            FavoriteSongsTable(
                tracks: filteredTracks,
                hoveredTrackID: hoveredFavoriteTrackID,
                selectedTrackID: selectedFavoriteTrackIDBinding,
                currentPlaybackTrackID: currentPlaybackTrackID,
                onHoverTrackChanged: { track, isHovered in
                    updateFavoriteTrackHover(for: track, isHovered: isHovered)
                },
                onPlayTrack: { track in
                    onPlayTrack(track, filteredTracks)
                }
            )
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("Loading Favorites")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Favorites Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                loadFavorites()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
        }
        .textSelection(.enabled)
    }

    private var favoriteSearchText: String {
        get {
            _favoriteSearchText.wrappedValue
        }
        nonmutating set {
            _favoriteSearchText.wrappedValue = newValue
        }
    }

    private var favoriteSearchTextBinding: Binding<String> {
        _favoriteSearchText.projectedValue
    }

    private var albums: [FavoriteAlbumEntry] {
        get {
            _albums.wrappedValue
        }
        nonmutating set {
            _albums.wrappedValue = newValue
        }
    }

    private var tracks: [FavoriteTrackEntry] {
        get {
            _tracks.wrappedValue
        }
        nonmutating set {
            _tracks.wrappedValue = newValue
        }
    }

    private var filteredTracks: [FavoriteTrackEntry] {
        let query = favoriteSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return tracks
        }

        return tracks.filter { track in
            track.title.localizedStandardContains(query)
                || track.albumTitle.localizedStandardContains(query)
        }
    }

    private var hoveredFavoriteAlbumID: String? {
        get {
            _hoveredFavoriteAlbumID.wrappedValue
        }
        nonmutating set {
            _hoveredFavoriteAlbumID.wrappedValue = newValue
        }
    }

    private var hoveredFavoriteTrackID: String? {
        get {
            _hoveredFavoriteTrackID.wrappedValue
        }
        nonmutating set {
            _hoveredFavoriteTrackID.wrappedValue = newValue
        }
    }

    private var currentPlaybackTrackID: String? {
        get {
            _currentPlaybackTrackID.wrappedValue
        }
        nonmutating set {
            _currentPlaybackTrackID.wrappedValue = newValue
        }
    }

    private var currentPlaybackTrackIDPublisher: AnyPublisher<String?, Never> {
        appState.playbackEngine.$currentItem
            .map { item in item?.track.id }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private var selectedFavoriteTrackIDBinding: Binding<String?> {
        _selectedFavoriteTrackID.projectedValue
    }

    private var isLoading: Bool {
        get {
            _isLoading.wrappedValue
        }
        nonmutating set {
            _isLoading.wrappedValue = newValue
        }
    }

    private var errorMessage: String? {
        get {
            _errorMessage.wrappedValue
        }
        nonmutating set {
            _errorMessage.wrappedValue = newValue
        }
    }

    private func loadFavorites() {
        isLoading = true
        errorMessage = nil

        do {
            albums = try appState.libraryStore.favoriteAlbums()
            tracks = try appState.libraryStore.favoriteTracks()
            hoveredFavoriteAlbumID = nil
            hoveredFavoriteTrackID = nil
            _selectedFavoriteTrackID.wrappedValue = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func open(_ album: FavoriteAlbumEntry) {
        guard let url = album.url else {
            return
        }

        onOpenAlbum(
            AlbumSummary(
                id: album.id,
                title: album.title,
                url: url,
                artworkURL: album.artworkURL,
                platforms: [],
                albumType: album.albumType,
                year: album.year,
                catalogNumber: nil
            )
        )
    }

    private func updateFavoriteAlbumHover(for album: FavoriteAlbumEntry, isHovered: Bool) {
        if isHovered {
            hoveredFavoriteAlbumID = album.id
        } else if hoveredFavoriteAlbumID == album.id {
            withAnimation(.easeOut(duration: FavoriteListLayout.hoverFadeDuration)) {
                hoveredFavoriteAlbumID = nil
            }
        }
    }

    private func updateFavoriteTrackHover(for track: FavoriteTrackEntry, isHovered: Bool) {
        if isHovered {
            hoveredFavoriteTrackID = track.id
        } else if hoveredFavoriteTrackID == track.id {
            withAnimation(.easeOut(duration: FavoriteListLayout.hoverFadeDuration)) {
                hoveredFavoriteTrackID = nil
            }
        }
    }
}

private struct FavoritesHeader: View {
    let category: FavoriteCategory
    let albumCount: Int
    let trackCount: Int
    let filteredTrackCount: Int
    let searchText: Binding<String>

    var body: some View {
        MusicListHeader(
            title: category == .songs ? "Songs" : "Albums",
            countLabel: category == .songs ? songCountLabel : albumCountLabel,
            searchText: category == .songs ? searchText : nil
        )
    }

    private var songCountLabel: String {
        if filteredTrackCount == trackCount {
            return "\(trackCount) songs"
        }

        return "\(filteredTrackCount) of \(trackCount) songs"
    }

    private var albumCountLabel: String {
        "\(albumCount) albums"
    }
}

private struct MusicListHeader: View {
    let title: String
    let countLabel: String
    let searchText: Binding<String>?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))

                Text(countLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            if let searchText {
                FavoriteSearchField(text: searchText)
            }
        }
        .padding(.horizontal, FavoriteListLayout.headerHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

private struct FavoriteAlbumRow: View {
    let entry: FavoriteAlbumEntry
    let isHovered: Bool
    let onHoverChanged: (Bool) -> Void
    let onOpen: () -> Void

    var body: some View {
        FavoriteRowSurface(isHovered: isHovered, onHoverChanged: onHoverChanged) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    FavoriteArtworkView(
                        localURL: entry.localArtworkURL,
                        remoteURL: entry.artworkURL,
                        size: FavoriteListLayout.albumArtworkSize
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)

                        Text(metadata)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(entry.url == nil)
            .accessibilityLabel(entry.title)
            .accessibilityHint("Open favorite album")
        }
    }

    private var metadata: String {
        var items: [String] = []

        if let year = entry.year {
            items.append(String(year))
        }

        if let albumType = entry.albumType, !albumType.isEmpty {
            items.append(albumType)
        }

        return items.isEmpty ? "Favorite Album" : items.joined(separator: " · ")
    }
}

private struct FavoriteTrackRow: View {
    let entry: FavoriteTrackEntry

    var body: some View {
        FavoriteSongTitleCell(
            entry: entry,
            isHovered: false,
            isPlaying: false,
            onHoverChanged: { _ in },
            onPlayTrack: { _ in }
        )
    }
}

private struct FavoriteSearchField: View {
    let text: Binding<String>

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search Songs", text: text)
                .textFieldStyle(.plain)

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear song search")
            }
        }
        .padding(.horizontal, SearchChromeMetrics.headerHorizontalPadding)
        .padding(.vertical, SearchChromeMetrics.headerVerticalPadding)
        .frame(width: FavoriteListLayout.searchFieldWidth)
        .frame(minHeight: SearchChromeMetrics.searchFieldHeight)
        .glassEffect(.regular, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(AdaptiveSystemColors.separator, lineWidth: 1)
        }
        .shadow(
            color: AdaptiveSystemColors.shadow.opacity(SearchChromeMetrics.shadowOpacity),
            radius: SearchChromeMetrics.shadowRadius,
            y: SearchChromeMetrics.shadowYOffset
        )
    }
}

private struct HistorySongsTable: View {
    let entries: [HistoryEntry]
    let hoveredTrackID: String?
    let selectedTrackID: Binding<String?>
    let currentPlaybackTrackID: String?
    let onHoverTrackChanged: (HistoryEntry, Bool) -> Void
    let onPlayTrack: (HistoryEntry) -> Void

    init(
        entries: [HistoryEntry],
        hoveredTrackID: String?,
        selectedTrackID: Binding<String?>,
        currentPlaybackTrackID: String?,
        onHoverTrackChanged: @escaping (HistoryEntry, Bool) -> Void,
        onPlayTrack: @escaping (HistoryEntry) -> Void
    ) {
        self.entries = entries
        self.hoveredTrackID = hoveredTrackID
        self.selectedTrackID = selectedTrackID
        self.currentPlaybackTrackID = currentPlaybackTrackID
        self.onHoverTrackChanged = onHoverTrackChanged
        self.onPlayTrack = onPlayTrack
    }

    var body: some View {
        Table(entries, selection: selectedTrackID) {
            TableColumn("Title") { entry in
                HistorySongTitleCell(
                    entry: entry,
                    isHovered: hoveredTrackID == entry.id,
                    isPlaying: currentPlaybackTrackID == entry.id,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    },
                    onPlayTrack: onPlayTrack
                )
            }
            .width(min: 280, ideal: 440)

            TableColumn("Album") { entry in
                HistorySongTextCell(
                    text: entry.albumTitle ?? entry.albumID,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    }
                )
            }
            .width(min: 180, ideal: 260)

            TableColumn("Last Played") { entry in
                HistorySongTextCell(
                    text: entry.playedAt.formatted(date: .abbreviated, time: .shortened),
                    isSecondary: true,
                    alignment: .trailing,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    }
                )
            }
            .width(min: 128, ideal: 156, max: 190)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            HistorySongsDoubleClickMonitor(
                selectedTrackID: selectedTrackID,
                tracks: entries,
                onPlayTrack: onPlayTrack
            )
        }
    }
}

private struct HistorySongTitleCell: View {
    let entry: HistoryEntry
    let isHovered: Bool
    let isPlaying: Bool
    let onHoverChanged: (Bool) -> Void
    let onPlayTrack: (HistoryEntry) -> Void

    var body: some View {
        HStack(spacing: 8) {
            leadingIcon

            Text(entry.title)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.callout)
        .contentShape(Rectangle())
        .onHover(perform: onHoverChanged)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if rowIconName.isEmpty {
            Color.clear
                .frame(width: FavoriteListLayout.songActionColumnWidth, height: 22)
        } else {
            Button {
                onPlayTrack(entry)
            } label: {
                Image(systemName: rowIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: FavoriteListLayout.songActionColumnWidth, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(rowIconName.isEmpty)
            .help("Play Song")
            .accessibilityLabel("Play \(entry.title)")
        }
    }

    private var rowIconName: String {
        if isPlaying {
            return "speaker.wave.2.fill"
        }

        return isHovered ? "play.fill" : ""
    }
}

private struct HistorySongTextCell: View {
    let text: String
    var isSecondary = false
    var alignment: Alignment = .leading
    let onHoverChanged: (Bool) -> Void

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(isSecondary ? .secondary : .primary)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
            .onHover(perform: onHoverChanged)
    }
}

private struct FavoriteSongsTable: View {
    let tracks: [FavoriteTrackEntry]
    let hoveredTrackID: String?
    let selectedTrackID: Binding<String?>
    let currentPlaybackTrackID: String?
    let onHoverTrackChanged: (FavoriteTrackEntry, Bool) -> Void
    let onPlayTrack: (FavoriteTrackEntry) -> Void

    init(
        tracks: [FavoriteTrackEntry],
        hoveredTrackID: String?,
        selectedTrackID: Binding<String?>,
        currentPlaybackTrackID: String?,
        onHoverTrackChanged: @escaping (FavoriteTrackEntry, Bool) -> Void,
        onPlayTrack: @escaping (FavoriteTrackEntry) -> Void
    ) {
        self.tracks = tracks
        self.hoveredTrackID = hoveredTrackID
        self.selectedTrackID = selectedTrackID
        self.currentPlaybackTrackID = currentPlaybackTrackID
        self.onHoverTrackChanged = onHoverTrackChanged
        self.onPlayTrack = onPlayTrack
    }

    var body: some View {
        Table(tracks, selection: selectedTrackID) {
            TableColumn("Title") { entry in
                FavoriteSongTitleCell(
                    entry: entry,
                    isHovered: hoveredTrackID == entry.id,
                    isPlaying: currentPlaybackTrackID == entry.id,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    },
                    onPlayTrack: onPlayTrack
                )
            }
            .width(min: 280, ideal: 440)

            TableColumn("Album") { entry in
                FavoriteSongTextCell(
                    text: entry.albumTitle,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    }
                )
            }
            .width(min: 180, ideal: 260)

            TableColumn("Date Added") { entry in
                FavoriteSongTextCell(
                    text: entry.createdAt.formatted(date: .abbreviated, time: .omitted),
                    isSecondary: true,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    }
                )
            }
            .width(min: 96, ideal: 118, max: 140)

            TableColumn("Time") { entry in
                FavoriteSongTextCell(
                    text: TrackFormatting.durationLabel(entry.duration),
                    isSecondary: true,
                    alignment: .trailing,
                    onHoverChanged: { isHovered in
                        onHoverTrackChanged(entry, isHovered)
                    }
                )
            }
            .width(min: 54, ideal: 64, max: 80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            FavoriteSongsDoubleClickMonitor(
                selectedTrackID: selectedTrackID,
                tracks: tracks,
                onPlayTrack: onPlayTrack
            )
        }
    }
}

private struct FavoriteSongTitleCell: View {
    let entry: FavoriteTrackEntry
    let isHovered: Bool
    let isPlaying: Bool
    let onHoverChanged: (Bool) -> Void
    let onPlayTrack: (FavoriteTrackEntry) -> Void

    var body: some View {
        HStack(spacing: 8) {
            leadingIcon

            Text(entry.title)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.callout)
        .contentShape(Rectangle())
        .onHover(perform: onHoverChanged)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if rowIconName.isEmpty {
            Color.clear
                .frame(width: FavoriteListLayout.songActionColumnWidth, height: 22)
        } else {
            Button {
                onPlayTrack(entry)
            } label: {
                Image(systemName: rowIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: FavoriteListLayout.songActionColumnWidth, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(rowIconName.isEmpty)
            .help("Play Song")
            .accessibilityLabel("Play \(entry.title)")
        }
    }

    private var rowIconName: String {
        if isPlaying {
            return "speaker.wave.2.fill"
        }

        return isHovered ? "play.fill" : ""
    }
}

private struct FavoriteSongTextCell: View {
    let text: String
    var isSecondary = false
    var alignment: Alignment = .leading
    let onHoverChanged: (Bool) -> Void

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(isSecondary ? .secondary : .primary)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
            .onHover(perform: onHoverChanged)
    }
}

private struct HistorySongsDoubleClickMonitor: NSViewRepresentable {
    let selectedTrackID: Binding<String?>
    let tracks: [HistoryEntry]
    let onPlayTrack: (HistoryEntry) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedTrackID: selectedTrackID,
            tracks: tracks,
            onPlayTrack: onPlayTrack
        )
    }

    func makeNSView(context: Context) -> MonitoringView {
        let view = MonitoringView()
        view.coordinator = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: MonitoringView, context: Context) {
        context.coordinator.selectedTrackID = selectedTrackID
        context.coordinator.tracks = tracks
        context.coordinator.onPlayTrack = onPlayTrack
        context.coordinator.view = nsView
        context.coordinator.refreshMonitor()
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class MonitoringView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.refreshMonitor()
        }
    }

    @MainActor
    final class Coordinator {
        weak var view: MonitoringView?
        var selectedTrackID: Binding<String?>
        var tracks: [HistoryEntry]
        var onPlayTrack: (HistoryEntry) -> Void
        private var eventMonitor: Any?

        init(
            selectedTrackID: Binding<String?>,
            tracks: [HistoryEntry],
            onPlayTrack: @escaping (HistoryEntry) -> Void
        ) {
            self.selectedTrackID = selectedTrackID
            self.tracks = tracks
            self.onPlayTrack = onPlayTrack
        }

        func refreshMonitor() {
            guard eventMonitor == nil, view?.window != nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func removeMonitor() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }

            eventMonitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent {
            guard event.clickCount >= 2,
                  let view,
                  let window = view.window,
                  event.window === window else {
                return event
            }

            let point = view.convert(event.locationInWindow, from: nil)

            guard view.bounds.contains(point) else {
                return event
            }

            guard let track = clickedTrack(for: event) else {
                return event
            }

            selectedTrackID.wrappedValue = track.id

            Task { @MainActor [weak self, track] in
                self?.onPlayTrack(track)
            }

            return event
        }

        private func clickedTrack(for event: NSEvent) -> HistoryEntry? {
            guard let tableView = tableView(for: event) else {
                return nil
            }

            let pointInTable = tableView.convert(event.locationInWindow, from: nil)
            let clickedRow = tableView.row(at: pointInTable)

            guard tracks.indices.contains(clickedRow) else {
                return nil
            }

            return tracks[clickedRow]
        }

        private func tableView(for event: NSEvent) -> NSTableView? {
            guard let window = view?.window,
                  let contentView = window.contentView,
                  event.window === window else {
                return nil
            }

            let pointInContent = contentView.convert(event.locationInWindow, from: nil)
            var hitView = contentView.hitTest(pointInContent)

            while let currentView = hitView {
                if let tableView = currentView as? NSTableView {
                    return tableView
                }

                hitView = currentView.superview
            }

            return nil
        }
    }
}

private struct FavoriteSongsDoubleClickMonitor: NSViewRepresentable {
    let selectedTrackID: Binding<String?>
    let tracks: [FavoriteTrackEntry]
    let onPlayTrack: (FavoriteTrackEntry) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedTrackID: selectedTrackID,
            tracks: tracks,
            onPlayTrack: onPlayTrack
        )
    }

    func makeNSView(context: Context) -> MonitoringView {
        let view = MonitoringView()
        view.coordinator = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: MonitoringView, context: Context) {
        context.coordinator.selectedTrackID = selectedTrackID
        context.coordinator.tracks = tracks
        context.coordinator.onPlayTrack = onPlayTrack
        context.coordinator.view = nsView
        context.coordinator.refreshMonitor()
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class MonitoringView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.refreshMonitor()
        }
    }

    @MainActor
    final class Coordinator {
        weak var view: MonitoringView?
        var selectedTrackID: Binding<String?>
        var tracks: [FavoriteTrackEntry]
        var onPlayTrack: (FavoriteTrackEntry) -> Void
        private var eventMonitor: Any?

        init(
            selectedTrackID: Binding<String?>,
            tracks: [FavoriteTrackEntry],
            onPlayTrack: @escaping (FavoriteTrackEntry) -> Void
        ) {
            self.selectedTrackID = selectedTrackID
            self.tracks = tracks
            self.onPlayTrack = onPlayTrack
        }

        func refreshMonitor() {
            guard eventMonitor == nil, view?.window != nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func removeMonitor() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }

            eventMonitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent {
            guard event.clickCount >= 2,
                  let view,
                  let window = view.window,
                  event.window === window else {
                return event
            }

            let point = view.convert(event.locationInWindow, from: nil)

            guard view.bounds.contains(point) else {
                return event
            }

            guard let track = clickedTrack(for: event) else {
                return event
            }

            selectedTrackID.wrappedValue = track.id

            Task { @MainActor [weak self, track] in
                self?.onPlayTrack(track)
            }

            return event
        }

        private func clickedTrack(for event: NSEvent) -> FavoriteTrackEntry? {
            guard let tableView = tableView(for: event) else {
                return nil
            }

            let pointInTable = tableView.convert(event.locationInWindow, from: nil)
            let clickedRow = tableView.row(at: pointInTable)

            guard tracks.indices.contains(clickedRow) else {
                return nil
            }

            return tracks[clickedRow]
        }

        private func tableView(for event: NSEvent) -> NSTableView? {
            guard let window = view?.window,
                  let contentView = window.contentView,
                  event.window === window else {
                return nil
            }

            let pointInContent = contentView.convert(event.locationInWindow, from: nil)
            var hitView = contentView.hitTest(pointInContent)

            while let currentView = hitView {
                if let tableView = currentView as? NSTableView {
                    return tableView
                }

                hitView = currentView.superview
            }

            return nil
        }
    }
}

private struct FavoriteRowSurface<Content: View>: View {
    let isHovered: Bool
    var isStriped = false
    var minHeight = FavoriteListLayout.albumRowHeight
    let onHoverChanged: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, FavoriteListLayout.rowHorizontalPadding)
            .padding(.vertical, FavoriteListLayout.rowVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundColor)
            }
            .contentShape(Rectangle())
            .onHover(perform: onHoverChanged)
    }

    private var backgroundColor: Color {
        if isHovered {
            return AdaptiveSystemColors.rowHoverBackground
        }

        return isStriped ? AdaptiveSystemColors.rowStripeBackground : Color.clear
    }
}

private struct FavoriteArtworkView: View {
    let localURL: URL?
    let remoteURL: URL?
    let size: CGFloat

    init(
        localURL: URL?,
        remoteURL: URL?,
        size: CGFloat = FavoriteListLayout.albumArtworkSize
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.size = size
    }

    var body: some View {
        Group {
            if let image = localImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var localImage: NSImage? {
        guard let localURL else {
            return nil
        }

        return NSImage(contentsOf: localURL)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.quaternary)

            Image(systemName: "music.note")
                .font(.system(size: max(12, size * 0.34), weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private enum FavoriteListLayout {
    static let headerHorizontalPadding: CGFloat = 28
    static let contentHorizontalPadding: CGFloat = 28
    static let rowHorizontalPadding: CGFloat = 10
    static let rowVerticalPadding: CGFloat = 4
    static let albumArtworkSize: CGFloat = 42
    static let trackArtworkSize: CGFloat = 34
    static let searchFieldWidth: CGFloat = 304
    static let songActionColumnWidth: CGFloat = 28
    static let albumRowHeight: CGFloat = 54
    static let trackRowHeight: CGFloat = 42
    static let headerHeight: CGFloat = 30
    static let columnSpacing: CGFloat = 14
    static let albumColumnWidth: CGFloat = 260
    static let addedColumnWidth: CGFloat = 112
    static let timeColumnWidth: CGFloat = 58
    static let hoverFadeDuration = 0.08
    static let albumSeparatorLeadingInset = rowHorizontalPadding + albumArtworkSize + 12
    static let trackSeparatorLeadingInset = rowHorizontalPadding + trackArtworkSize + 10
}
