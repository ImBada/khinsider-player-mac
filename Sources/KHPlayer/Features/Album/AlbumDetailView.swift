import SwiftUI
import AppKit

internal struct AlbumDetailView: View {
    @StateObject private var viewModel: AlbumDetailViewModel
    @ObservedObject private var playbackEngine: PlaybackEngine
    private var _scrollOffsetY = State<CGFloat>(initialValue: 0)
    private var _selectedTrackID = State<String?>(initialValue: nil)
    private var _hoveredTrackID = State<String?>(initialValue: nil)

    private let onBack: () -> Void
    private let onPlay: (AlbumDetail, Track) -> Void

    internal init(
        summary: AlbumSummary,
        client: KHClient,
        libraryStore: LibraryStore,
        artworkCache: ArtworkCache? = nil,
        playbackEngine: PlaybackEngine,
        onBack: @escaping () -> Void,
        onPlay: @escaping (AlbumDetail, Track) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AlbumDetailViewModel(
                summary: summary,
                client: client,
                libraryStore: libraryStore,
                artworkCache: artworkCache
            )
        )
        self.playbackEngine = playbackEngine
        self.onBack = onBack
        self.onPlay = onPlay
    }

    internal var body: some View {
        content
            .task {
                await viewModel.load()
            }
    }

    private var scrollOffsetY: CGFloat {
        get {
            _scrollOffsetY.wrappedValue
        }
        nonmutating set {
            _scrollOffsetY.wrappedValue = newValue
        }
    }

    private var selectedTrackID: String? {
        get {
            _selectedTrackID.wrappedValue
        }
        nonmutating set {
            _selectedTrackID.wrappedValue = newValue
        }
    }

    private var hoveredTrackID: String? {
        get {
            _hoveredTrackID.wrappedValue
        }
        nonmutating set {
            _hoveredTrackID.wrappedValue = newValue
        }
    }

    @ViewBuilder
    private var content: some View {
        if let album = viewModel.album {
            albumContent(album)
        } else if viewModel.isLoading {
            loadingState
        } else if let errorMessage = viewModel.errorMessage {
            errorState(message: errorMessage)
        } else {
            loadingState
        }
    }

    private func albumContent(_ album: AlbumDetail) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    header(album)
                        .padding(.horizontal, 52)
                        .padding(.top, AlbumDetailLayout.headerTopPadding)
                        .padding(.bottom, 30)

                    trackList(album)
                        .padding(.horizontal, 52)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 120)
            }
            .modifier(ScrollOffsetTrackingModifier { offsetY in
                scrollOffsetY = offsetY
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            collapsedTopBar(album: album, isVisible: shouldShowCollapsedTopBar)
                .zIndex(AlbumDetailLayout.collapsedTopBarZIndex)

            albumTopBarDragArea(isVisible: shouldShowCollapsedTopBar)
                .zIndex(AlbumDetailLayout.topBarDragAreaZIndex)

            AlbumTopControls(
                albumURL: album.url,
                onBack: onBack,
                onOpenInBrowser: openAlbumInBrowser
            )
                .padding(.horizontal, AlbumDetailLayout.topControlHorizontalPadding)
                .padding(.top, AlbumDetailLayout.topControlsTopPadding)
                .zIndex(AlbumDetailLayout.topControlsZIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shouldShowCollapsedTopBar: Bool {
        scrollOffsetY >= AlbumDetailLayout.metadataLineCollapseOffset
    }

    private func collapsedTopBar(album: AlbumDetail, isVisible: Bool) -> some View {
        AlbumCollapsedTopBar(
            title: album.title,
            subtitle: collapsedSubtitle(for: album),
            isVisible: isVisible
        )
        .animation(.easeInOut(duration: 0.16), value: isVisible)
    }

    private func albumTopBarDragArea(isVisible: Bool) -> some View {
        AlbumTopBarDragArea(isVisible: isVisible)
            .frame(height: AlbumDetailLayout.collapsedTopBarHeight)
            .frame(maxWidth: .infinity, alignment: .top)
            .accessibilityHidden(true)
    }

    private func header(_ album: AlbumDetail) -> some View {
        HStack(alignment: .bottom, spacing: 28) {
            AlbumArtworkView(url: album.artworkURL ?? viewModel.summary.artworkURL)
                .shadow(color: AdaptiveSystemColors.shadow.opacity(0.28), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(album.title)
                    .font(.system(size: 32, weight: .bold))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let credit = primaryCredit(for: album) {
                    Text(credit)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !metadataItems(for: album).isEmpty {
                    Text(metadataItems(for: album).joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let description = album.description, !description.isEmpty {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                AlbumActionBar(
                    album: album,
                    isFavorite: viewModel.isAlbumFavorite,
                    onPlay: onPlay,
                    onToggleFavorite: viewModel.toggleAlbumFavorite
                )
                    .padding(.top, 20)
            }
            .padding(.bottom, 4)
            .frame(maxWidth: 760, alignment: .leading)

            Spacer(minLength: 24)
        }
    }

    private func trackList(_ album: AlbumDetail) -> some View {
        VStack(spacing: 0) {
            if album.tracks.isEmpty {
                ContentUnavailableView(
                    "No Tracks Found",
                    systemImage: "music.note.list",
                    description: Text("This album page did not include playable tracks.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(trackGroups(for: album)) { group in
                        if let title = group.title {
                            TrackDiscSectionHeader(title: title)
                        }

                        ForEach(group.tracks) { track in
                            TrackRow(
                                album: album,
                                track: track,
                                isPlaying: isPlaying(track: track, in: album),
                                isSelected: selectedTrackID == track.id,
                                isHovered: hoveredTrackID == track.id,
                                isFavorite: viewModel.favoriteTrackIDs.contains(track.id),
                                onSelect: {
                                    selectedTrackID = track.id
                                },
                                onHoverChanged: { isHovered in
                                    updateHover(for: track, isHovered: isHovered)
                                },
                                onToggleFavorite: {
                                    viewModel.toggleTrackFavorite(track)
                                },
                                onPlay: onPlay
                            )

                            Divider()
                                .padding(.leading, TrackColumns.rowSeparatorLeadingInset)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func updateHover(for track: Track, isHovered: Bool) {
        if isHovered {
            hoveredTrackID = track.id
        } else if hoveredTrackID == track.id {
            withAnimation(.easeOut(duration: TrackColumns.hoverFadeDuration)) {
                hoveredTrackID = nil
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("Loading Album")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Album Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                Task {
                    await viewModel.load()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
        }
        .textSelection(.enabled)
    }

    private func primaryCredit(for album: AlbumDetail) -> String? {
        if let publisher = album.publisher, !publisher.isEmpty {
            return publisher
        }

        return album.alternativeTitles.first
    }

    private func metadataItems(for album: AlbumDetail) -> [String] {
        var items: [String] = []

        if let year = album.year {
            items.append(String(year))
        }

        if let albumType = album.albumType, !albumType.isEmpty {
            items.append(albumType)
        }

        if !album.platforms.isEmpty {
            items.append(album.platforms.joined(separator: ", "))
        }

        if let fileCount = album.fileCount {
            items.append("\(fileCount) files")
        }

        if let duration = album.totalDuration {
            items.append("Total \(TrackFormatting.durationLabel(duration))")
        }

        return items
    }

    private func collapsedSubtitle(for album: AlbumDetail) -> String {
        var items: [String] = []

        if let fileCount = album.fileCount {
            items.append("\(fileCount) files")
        }

        if let duration = album.totalDuration {
            items.append(TrackFormatting.durationLabel(duration))
        }

        return items.joined(separator: " · ")
    }

    private func trackGroups(for album: AlbumDetail) -> [TrackDiscGroup] {
        let discNumbers = Set(album.tracks.compactMap(\.discNumber))
        guard discNumbers.count > 1 else {
            return [
                TrackDiscGroup(
                    id: "all",
                    title: nil,
                    tracks: album.tracks
                )
            ]
        }

        var groups: [TrackDiscGroup] = []
        var currentDiscNumber: Int?
        var currentTracks: [Track] = []

        for track in album.tracks {
            let discNumber = track.discNumber ?? 1
            if currentDiscNumber == nil {
                currentDiscNumber = discNumber
            } else if currentDiscNumber != discNumber {
                appendTrackGroup(
                    discNumber: currentDiscNumber,
                    tracks: currentTracks,
                    to: &groups
                )
                currentDiscNumber = discNumber
                currentTracks = []
            }

            currentTracks.append(track)
        }

        appendTrackGroup(
            discNumber: currentDiscNumber,
            tracks: currentTracks,
            to: &groups
        )

        return groups
    }

    private func appendTrackGroup(
        discNumber: Int?,
        tracks: [Track],
        to groups: inout [TrackDiscGroup]
    ) {
        guard let discNumber, !tracks.isEmpty else {
            return
        }

        groups.append(
            TrackDiscGroup(
                id: "disc-\(discNumber)-\(groups.count)",
                title: "디스크 \(discNumber)",
                tracks: tracks
            )
        )
    }

    private func isPlaying(track: Track, in album: AlbumDetail) -> Bool {
        guard let currentItem = playbackEngine.currentItem else {
            return false
        }

        return currentItem.album.id == album.id && currentItem.track.id == track.id
    }

    private func openAlbumInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

private struct TrackDiscGroup: Identifiable {
    let id: String
    let title: String?
    let tracks: [Track]
}

private struct AlbumCollapsedTopBar: View {
    let title: String
    let subtitle: String
    let isVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.leading, 80)
            .padding(.trailing, 80)
            .frame(height: AlbumDetailLayout.collapsedTopBarHeight, alignment: .center)

            Divider()
                .opacity(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(AdaptiveSystemColors.chromeOverlayBackground)
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(false)
    }
}

private struct AlbumTopBarDragArea: NSViewRepresentable {
    let isVisible: Bool

    func makeNSView(context: Context) -> DragAreaView {
        let view = DragAreaView()
        view.isVisible = isVisible
        return view
    }

    func updateNSView(_ nsView: DragAreaView, context: Context) {
        nsView.isVisible = isVisible
    }

    final class DragAreaView: NSView {
        var isVisible = false

        override var acceptsFirstResponder: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard isVisible, bounds.contains(point) else {
                return nil
            }

            return controlExclusionRects.contains { rect in
                rect.contains(point)
            } ? nil : self
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        private var controlExclusionRects: [NSRect] {
            let width = AlbumDetailLayout.topControlHorizontalPadding + AlbumDetailLayout.topControlButtonSize
            let leadingRect = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: bounds.height
            )
            let trailingRect = NSRect(
                x: max(0, bounds.width - width),
                y: 0,
                width: width,
                height: bounds.height
            )

            return [leadingRect, trailingRect]
        }
    }
}

private enum AlbumDetailLayout {
    static let artworkSize: CGFloat = 220
    static let artworkCornerRadius: CGFloat = 6
    static let metadataLineCollapseOffset: CGFloat = 130
    static let headerTopPadding: CGFloat = 54
    static let topControlsTopPadding: CGFloat = 10
    static let topControlHorizontalPadding: CGFloat = 22
    static let topControlButtonSize: CGFloat = 52
    static let topControlContentSize: CGFloat = 28
    static let actionButtonHeight: CGFloat = 36
    static let actionPlayButtonMinWidth: CGFloat = 118
    static let actionShuffleIconSize: CGFloat = 14
    static let collapsedTopBarHeight = topControlButtonSize
    static let collapsedTopBarZIndex: Double = 10
    static let topBarDragAreaZIndex: Double = 15
    static let topControlsZIndex: Double = 20
}

private struct ScrollOffsetTrackingModifier: ViewModifier {
    let onScroll: (CGFloat) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y)
                } action: { _, newValue in
                    onScroll(newValue)
                }
        } else {
            content
                .background {
                    ScrollOffsetObserver { offsetY in
                        onScroll(offsetY)
                    }
                }
        }
    }
}

@MainActor
private struct ScrollOffsetObserver: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll

        DispatchQueue.main.async {
            context.coordinator.attach(from: nsView)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onScroll: (CGFloat) -> Void
        private weak var observedClipView: NSClipView?
        private var initialOffsetY: CGFloat?

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(from view: NSView) {
            guard let scrollView = nearestScrollView(from: view) else {
                return
            }

            let clipView = scrollView.contentView

            guard observedClipView !== clipView else {
                publish(from: scrollView)
                return
            }

            detach()
            observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
            publish(from: scrollView)
        }

        @objc private func boundsDidChange(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView else {
                return
            }

            publish(offsetY: clipView.bounds.origin.y)
        }

        private func publish(from scrollView: NSScrollView) {
            let offsetY = scrollView.contentView.bounds.origin.y
            publish(offsetY: offsetY)
        }

        private func publish(offsetY: CGFloat) {
            if initialOffsetY == nil {
                initialOffsetY = offsetY
            }

            let deltaY = abs(offsetY - (initialOffsetY ?? offsetY))
            onScroll(deltaY)
        }

        private func detach() {
            if let observedClipView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClipView
                )
            }

            observedClipView = nil
            initialOffsetY = nil
        }

        private func nearestScrollView(from view: NSView) -> NSScrollView? {
            if let enclosingScrollView = view.enclosingScrollView {
                return enclosingScrollView
            }

            var candidate = view.superview

            while let currentView = candidate {
                if let scrollView = currentView as? NSScrollView {
                    return scrollView
                }

                if let scrollView = findScrollView(in: currentView) {
                    return scrollView
                }

                candidate = currentView.superview
            }

            return nil
        }

        private func findScrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }

            for subview in view.subviews {
                if let scrollView = findScrollView(in: subview) {
                    return scrollView
                }
            }

            return nil
        }
    }
}

private struct AlbumActionBar: View {
    let album: AlbumDetail
    let isFavorite: Bool
    let onPlay: (AlbumDetail, Track) -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let randomTrack = album.tracks.randomElement() {
                    onPlay(album, randomTrack)
                }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: AlbumDetailLayout.actionShuffleIconSize, weight: .bold))
                    .frame(
                        width: AlbumDetailLayout.actionButtonHeight,
                        height: AlbumDetailLayout.actionButtonHeight
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(.quaternary)
            .clipShape(Circle())
            .disabled(album.tracks.isEmpty)
            .help("Shuffle")
            .accessibilityLabel("Shuffle")

            Button {
                if let firstTrack = album.tracks.first {
                    onPlay(album, firstTrack)
                }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(
                        minWidth: AlbumDetailLayout.actionPlayButtonMinWidth,
                        minHeight: AlbumDetailLayout.actionButtonHeight
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.accentColor)
            .disabled(album.tracks.isEmpty)
            .keyboardShortcut(.defaultAction)
            .help("Play")

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "checkmark" : "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(
                        width: AlbumDetailLayout.actionButtonHeight,
                        height: AlbumDetailLayout.actionButtonHeight
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(.quaternary)
            .clipShape(Circle())
            .help(isFavorite ? "Remove Album from Favorites" : "Add Album to Favorites")
            .accessibilityLabel(isFavorite ? "Remove album from favorites" : "Add album to favorites")
        }
    }
}

private struct AlbumTopControls: View {
    let albumURL: URL
    let onBack: () -> Void
    let onOpenInBrowser: (URL) -> Void

    var body: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(
                        width: AlbumDetailLayout.topControlContentSize,
                        height: AlbumDetailLayout.topControlContentSize
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Back")
            .accessibilityLabel("Back")

            Spacer()

            Menu {
                Button {
                    onOpenInBrowser(albumURL)
                } label: {
                    Label("View on Web", systemImage: "safari")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(
                        width: AlbumDetailLayout.topControlContentSize,
                        height: AlbumDetailLayout.topControlContentSize
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .menuIndicator(.hidden)
            .help("More")
            .accessibilityLabel("More")
        }
    }
}

private struct AlbumArtworkView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
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
        .frame(
            width: AlbumDetailLayout.artworkSize,
            height: AlbumDetailLayout.artworkSize
        )
        .background(.quaternary)
        .clipShape(artworkShape)
    }

    private var artworkShape: some Shape {
        RoundedRectangle(
            cornerRadius: AlbumDetailLayout.artworkCornerRadius,
            style: .continuous
        )
    }

    private var placeholder: some View {
        ZStack {
            artworkShape
                .fill(.quaternary)

            Image(systemName: "music.note")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct TrackRow: View {
    let album: AlbumDetail
    let track: Track
    let isPlaying: Bool
    let isSelected: Bool
    let isHovered: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onToggleFavorite: () -> Void
    let onPlay: (AlbumDetail, Track) -> Void

    private var _isLeadingPlayPressed = State<Bool>(initialValue: false)

    fileprivate init(
        album: AlbumDetail,
        track: Track,
        isPlaying: Bool,
        isSelected: Bool,
        isHovered: Bool,
        isFavorite: Bool,
        onSelect: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onToggleFavorite: @escaping () -> Void,
        onPlay: @escaping (AlbumDetail, Track) -> Void
    ) {
        self.album = album
        self.track = track
        self.isPlaying = isPlaying
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isFavorite = isFavorite
        self.onSelect = onSelect
        self.onHoverChanged = onHoverChanged
        self.onToggleFavorite = onToggleFavorite
        self.onPlay = onPlay
    }

    private var isLeadingPlayPressed: Bool {
        get {
            _isLeadingPlayPressed.wrappedValue
        }
        nonmutating set {
            _isLeadingPlayPressed.wrappedValue = newValue
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            TrackRowHoverTrackingView(
                leadingExtension: TrackColumns.favoriteOutsideInset,
                onHoverChanged: { isHovered in
                    onHoverChanged(isHovered)
                },
                onFavoriteClick: onToggleFavorite
            )
            .frame(maxWidth: .infinity, minHeight: TrackColumns.rowHitHeight)
            .accessibilityHidden(true)

            rowSurface
                .overlay(alignment: .leading) {
                    favoriteButton
                        .offset(x: -TrackColumns.favoriteOutsideInset)
                }
                .overlay {
                    TrackRowInteractionView(
                        isLeadingPlayEnabled: !isPlaying,
                        leadingPlayHitWidth: TrackColumns.leadingPlayHitWidth,
                        onSelect: onSelect,
                        onLeadingPlayPress: showLeadingPlayPressFeedback,
                        onPlay: {
                            onPlay(album, track)
                        }
                    )
                    .accessibilityHidden(true)
                }
        }
        .frame(maxWidth: .infinity, minHeight: TrackColumns.rowHitHeight, alignment: .leading)
        .contentShape(Rectangle())
        .onDisappear {
            onHoverChanged(false)
            self.isLeadingPlayPressed = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.number). \(track.title)")
        .accessibilityHint("Double-click to play")
    }

    private var rowSurface: some View {
        HStack(spacing: TrackColumns.spacing) {
            numberColumn

            Text(track.title)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(TrackFormatting.durationLabel(track.duration))
                .monospacedDigit()
                .frame(width: TrackColumns.duration, alignment: .trailing)
        }
        .font(.callout)
        .foregroundStyle(isSelected ? AdaptiveSystemColors.selectedText : Color.primary)
        .frame(minHeight: 32)
        .padding(.horizontal, TrackColumns.rowHorizontalPadding)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor : hoverBackground)
        }
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.accentColor : favoriteHoverColor)
                .frame(width: TrackColumns.favorite, height: 24)
                .opacity(isFavorite || isHovered ? 1 : 0)
        }
        .buttonStyle(.plain)
        .frame(width: TrackColumns.favoriteGutter, height: 32)
        .background(Color.clear)
        .contentShape(Rectangle())
        .help(isFavorite ? "Remove Song from Favorites" : "Add Song to Favorites")
        .accessibilityLabel(isFavorite ? "Remove song from favorites" : "Add song to favorites")
    }

    @ViewBuilder
    private var numberColumn: some View {
        if isPlaying {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? AdaptiveSystemColors.selectedText : Color.accentColor)
                .frame(width: TrackColumns.number, alignment: .trailing)
        } else if isHovered {
            Image(systemName: "play.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(leadingPlayColor)
                .scaleEffect(isLeadingPlayPressed ? 0.88 : 1)
                .animation(.easeOut(duration: 0.12), value: isLeadingPlayPressed)
                .frame(width: TrackColumns.number, alignment: .trailing)
        } else {
            Text("\(track.number)")
                .monospacedDigit()
                .frame(width: TrackColumns.number, alignment: .trailing)
        }
    }

    private var hoverBackground: Color {
        isHovered && !isPlaying ? AdaptiveSystemColors.rowHoverBackground : Color.clear
    }

    private var leadingPlayColor: Color {
        if isSelected {
            return isLeadingPlayPressed
                ? AdaptiveSystemColors.selectedText.opacity(0.66)
                : AdaptiveSystemColors.selectedText
        }

        return isLeadingPlayPressed ? Color.accentColor.opacity(0.58) : Color.accentColor
    }

    private var favoriteHoverColor: Color {
        Color.accentColor
    }

    private func showLeadingPlayPressFeedback() {
        withAnimation(.easeOut(duration: 0.08)) {
            isLeadingPlayPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.12)) {
                isLeadingPlayPressed = false
            }
        }
    }
}

private struct TrackDiscSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .padding(.leading, TrackColumns.rowHorizontalPadding)
    }
}

private struct TrackRowHoverTrackingView: NSViewRepresentable {
    let leadingExtension: CGFloat
    let onHoverChanged: (Bool) -> Void
    let onFavoriteClick: () -> Void

    func makeNSView(context: Context) -> HoverView {
        let view = HoverView()
        view.leadingExtension = leadingExtension
        view.onHoverChanged = onHoverChanged
        view.onFavoriteClick = onFavoriteClick
        return view
    }

    func updateNSView(_ nsView: HoverView, context: Context) {
        nsView.leadingExtension = leadingExtension
        nsView.onHoverChanged = onHoverChanged
        nsView.onFavoriteClick = onFavoriteClick
        nsView.refreshTrackingArea()
    }

    final class HoverView: NSView {
        var leadingExtension: CGFloat = 0
        var onHoverChanged: ((Bool) -> Void)?
        var onFavoriteClick: (() -> Void)?
        private var trackingArea: NSTrackingArea?
        private var eventMonitor: Any?
        private var isHovering = false

        isolated deinit {
            NotificationCenter.default.removeObserver(self)
            removeEventMonitor()
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                setHovering(false)
                removeEventMonitor()
            } else {
                installEventMonitor()
            }
            installScrollBoundsObserver()
            updateHoverState()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            installScrollBoundsObserver()
            updateHoverState()
        }

        override func setFrameOrigin(_ newOrigin: NSPoint) {
            super.setFrameOrigin(newOrigin)
            updateHoverState()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            updateHoverState()
        }

        override func setBoundsSize(_ newSize: NSSize) {
            super.setBoundsSize(newSize)
            updateHoverState()
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            refreshTrackingArea()
        }

        func refreshTrackingArea() {
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }

            let trackingArea = NSTrackingArea(
                rect: trackingRect,
                options: [
                    .activeInKeyWindow,
                    .mouseEnteredAndExited,
                    .mouseMoved
                ],
                owner: self
            )
            self.trackingArea = trackingArea
            addTrackingArea(trackingArea)
            updateHoverState()
        }

        override func mouseEntered(with event: NSEvent) {
            setHovering(true)
        }

        override func mouseMoved(with event: NSEvent) {
            updateHoverState(with: event)
        }

        override func mouseExited(with event: NSEvent) {
            updateHoverState(with: event)
        }

        private func updateHoverState(with event: NSEvent? = nil) {
            let point: NSPoint
            if let event {
                guard let window, event.window === window else {
                    setHovering(false)
                    return
                }
                point = convert(event.locationInWindow, from: nil)
            } else if let window {
                point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            } else {
                setHovering(false)
                return
            }

            setHovering(trackingRect.contains(point))
        }

        private func setHovering(_ isHovering: Bool) {
            guard self.isHovering != isHovering else {
                return
            }

            self.isHovering = isHovering
            onHoverChanged?(isHovering)
        }

        private var trackingRect: NSRect {
            NSRect(
                x: -leadingExtension,
                y: 0,
                width: bounds.width + leadingExtension,
                height: bounds.height
            )
        }

        private var favoriteTrackingRect: NSRect {
            NSRect(
                x: -leadingExtension,
                y: 0,
                width: leadingExtension,
                height: bounds.height
            )
        }

        private func installEventMonitor() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
                guard let self else {
                    return event
                }

                switch event.type {
                case .mouseMoved:
                    updateHoverState(with: event)
                    return event
                case .leftMouseDown where isFavoriteClickLocation(event):
                    onFavoriteClick?()
                    return nil
                case .leftMouseDown:
                    updateHoverState(with: event)
                    return event
                default:
                    return event
                }
            }
        }

        private func removeEventMonitor() {
            guard let eventMonitor else {
                return
            }

            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        private func isFavoriteClickLocation(_ event: NSEvent) -> Bool {
            guard let window, event.window === window else {
                return false
            }

            let point = convert(event.locationInWindow, from: nil)
            return favoriteTrackingRect.contains(point)
        }

        private func installScrollBoundsObserver() {
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.boundsDidChangeNotification,
                object: nil
            )

            guard let clipView = enclosingScrollView?.contentView else {
                return
            }

            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

        @objc private func scrollBoundsDidChange(_ notification: Notification) {
            updateHoverState()
        }
    }
}

private struct TrackRowInteractionView: NSViewRepresentable {
    let isLeadingPlayEnabled: Bool
    let leadingPlayHitWidth: CGFloat
    let onSelect: () -> Void
    let onLeadingPlayPress: () -> Void
    let onPlay: () -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.isLeadingPlayEnabled = isLeadingPlayEnabled
        view.leadingPlayHitWidth = leadingPlayHitWidth
        view.onSelect = onSelect
        view.onLeadingPlayPress = onLeadingPlayPress
        view.onPlay = onPlay
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.isLeadingPlayEnabled = isLeadingPlayEnabled
        nsView.leadingPlayHitWidth = leadingPlayHitWidth
        nsView.onSelect = onSelect
        nsView.onLeadingPlayPress = onLeadingPlayPress
        nsView.onPlay = onPlay
    }

    final class InteractionView: NSView {
        var isLeadingPlayEnabled = false
        var leadingPlayHitWidth: CGFloat = 0
        var onSelect: (() -> Void)?
        var onLeadingPlayPress: (() -> Void)?
        var onPlay: (() -> Void)?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            return bounds.contains(point) ? self : nil
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            onSelect?()

            let point = convert(event.locationInWindow, from: nil)
            if isLeadingPlayEnabled && point.x <= leadingPlayHitWidth {
                onLeadingPlayPress?()
                onPlay?()
                return
            }

            if event.clickCount >= 2 {
                onPlay?()
            }
        }

        override func scrollWheel(with event: NSEvent) {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

private enum TrackColumns {
    static let favorite: CGFloat = 24
    static let favoriteGutter: CGFloat = 24
    static let number: CGFloat = 22
    static let duration: CGFloat = 72
    static let spacing: CGFloat = 10
    static let gutterSpacing: CGFloat = 6
    static let rowHorizontalPadding: CGFloat = 4
    static let rowHitHeight: CGFloat = 42
    static let hoverFadeDuration = 0.08
    static let favoriteOutsideInset = favoriteGutter + gutterSpacing
    static let rowSeparatorLeadingInset = rowHorizontalPadding + number + spacing
    static let leadingPlayHitWidth = rowHorizontalPadding + number + spacing
}

internal enum TrackFormatting {
    static func durationLabel(_ duration: TimeInterval?) -> String {
        guard let duration else {
            return "-"
        }

        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):\(twoDigits(minutes)):\(twoDigits(seconds))"
        }

        return "\(minutes):\(twoDigits(seconds))"
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
