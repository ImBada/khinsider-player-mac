import Foundation

@main
struct DesignBehaviorChecks {
    static func main() throws {
        try checkAlbumHeaderUsesMusicStyleLayout()
        try checkMiniPlayerFloatsOverContent()
        try checkTrackListUsesMusicStyleDiscSections()
        try checkAlbumTopChromeOnlyShowsBackButton()
        try checkAlbumDetailUsesSinglePageScroll()
        try checkAlbumTopBarAppearsOnlyAfterScrolling()
        try checkAppWindowDoesNotRenderPersistentTitleBar()
        try checkAppWindowAllowsCompactPlaybackFriendlySize()
        try checkAlbumDetailStartsAtTopAfterHidingTitleBar()
        try checkSearchViewUsesFloatingSearchField()
        try checkSearchAndBackControlsKeepReliableHitTargets()
        try checkSearchClearsResultsInsteadOfOverlayingLoading()
        try checkSearchStateSurvivesAlbumDetailNavigation()
        try checkAlbumDetailOverlaysDestinationInsteadOfReplacingIt()
        try checkAlbumTopControlsMatchMusicChromePlacement()
        try checkCollapsedAlbumTopBarStaysCompact()
        try checkAlbumDetailUsesSystemAccentColor()
        try checkSourceUsesAdaptiveSystemColors()
        try checkAlbumTopControlsUseNativeGlassOnly()
        try checkAlbumActionButtonsStayCompact()
        try checkFavoritesUseAlbumAndSongCategories()
        try checkFavoritesListsUseMusicHoverAndSongTable()
        try checkAlbumAndTrackFavoriteControlsMatchMusicBehavior()
        try checkMiniPlayerVolumeControlMatchesMusicBehavior()
        try checkMiniPlayerPlaybackFaderMatchesMusicBehavior()
        try checkMiniPlayerShowsCurrentAlbumArtwork()
        try checkMiniPlayerArtworkNavigatesToCurrentAlbum()
        try checkSidebarStaysVisible()
        try checkSidebarUsesStableNavigationTopMargin()
        try checkHistoryRefreshDoesNotDriveWindowToolbar()
        try checkAlbumTracksUseDoubleClickAndPlayingHighlight()
        try checkPlaybackIsMP3Only()
    }

    private static func checkAlbumHeaderUsesMusicStyleLayout() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("AlbumActionBar("))
        precondition(source.contains("static let artworkSize: CGFloat = 220"))
        precondition(source.contains("static let artworkCornerRadius: CGFloat = 6"))
        precondition(source.contains("width: AlbumDetailLayout.artworkSize"))
        precondition(source.contains("height: AlbumDetailLayout.artworkSize"))
        precondition(source.contains("cornerRadius: AlbumDetailLayout.artworkCornerRadius"))
        precondition(!source.contains("Spacer(minLength: 0)\n\n                Button"))
        precondition(!source.contains("items.append(\"MP3 \\(totalMP3Size)\")"))
        precondition(!source.contains("items.append(\"FLAC \\(totalFLACSize)\")"))
    }

    private static func checkMiniPlayerFloatsOverContent() throws {
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")
        let miniPlayer = try sourceFile("Sources/KHPlayer/Features/Player/MiniPlayerView.swift")

        precondition(contentView.contains("ZStack(alignment: .bottom)"))
        precondition(!contentView.contains("Divider()\n\n                MiniPlayerView()"))
        precondition(!contentView.contains(".padding(.bottom, optionalAppState == nil ? 0 : 82)"))
        precondition(miniPlayer.contains(".glassEffect(.regular.interactive(), in: Capsule(style: .continuous))"))
        precondition(miniPlayer.components(separatedBy: ".glassEffect(.regular.interactive(), in: Capsule(style: .continuous))").count == 3)
        precondition(miniPlayer.contains("MiniPlayerTransportControls("))
        precondition(miniPlayer.contains("private struct MiniPlayerTransportControls: View"))
        precondition(miniPlayer.contains("shuffleButton"))
        precondition(miniPlayer.contains("Button(action: onToggleShuffle)"))
        precondition(miniPlayer.contains(".foregroundStyle(isShuffleEnabled ? Color.accentColor : Color(nsColor: .disabledControlTextColor))"))
        precondition(miniPlayer.contains(".opacity(isShuffleEnabled ? 1 : 0.8)"))
        precondition(!miniPlayer.contains(".accessibilityLabel(\"Shuffle unavailable\")"))
        precondition(miniPlayer.contains("previousButton"))
        precondition(miniPlayer.contains("playPauseButton"))
        precondition(miniPlayer.contains("nextButton"))
        precondition(miniPlayer.contains("repeatButton"))
        precondition(miniPlayer.contains(".foregroundStyle(repeatForegroundColor)"))
        precondition(miniPlayer.contains("repeatMode == .off ? Color(nsColor: .disabledControlTextColor) : Color.accentColor"))
        precondition(!miniPlayer.contains(".foregroundStyle(.primary)\n            .contentShape(Rectangle())"))
        precondition(miniPlayer.contains("static let transportControlHeight: CGFloat = 38"))
        precondition(miniPlayer.contains("static let playButtonIconSize: CGFloat = 24"))
        precondition(miniPlayer.contains("static let artworkSize: CGFloat = 34"))
        precondition(miniPlayer.contains(".frame(maxWidth: 640, minHeight: 50)"))
        precondition(miniPlayer.contains(".buttonStyle(.plain)"))
        precondition(miniPlayer.contains(".frame(maxWidth: 640"))
        precondition(!miniPlayer.contains(".background(.regularMaterial)"))
        precondition(!miniPlayer.contains(".clipShape(Capsule())"))
        precondition(!miniPlayer.contains(".buttonStyle(.glass)"))
    }

    private static func checkTrackListUsesMusicStyleDiscSections() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("TrackRow("))
        precondition(source.contains("private var _hoveredTrackID = State<String?>(initialValue: nil)"))
        precondition(source.contains("isHovered: hoveredTrackID == track.id"))
        precondition(source.contains("TrackDiscSectionHeader(title: title)"))
        precondition(source.contains("private func trackGroups(for album: AlbumDetail) -> [TrackDiscGroup]"))
        precondition(!source.contains("TrackTableHeader("))
        precondition(!source.contains("TrackColumns.size"))
        precondition(!source.contains("trackSize(for: track, preferredFormat: preferredFormat)"))
        precondition(!source.contains("Text(\"MP3\")"))
        precondition(!source.contains("Text(\"FLAC\")"))
    }

    private static func checkPlaybackIsMP3Only() throws {
        let appState = try sourceFile("Sources/KHPlayer/App/AppState.swift")
        let settingsView = try sourceFile("Sources/KHPlayer/Features/Settings/SettingsView.swift")
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")
        let models = try sourceFile("Sources/KHPlayer/Domain/Models.swift")
        let trackDetailParser = try sourceFile("Sources/KHPlayer/Parsing/TrackDetailParser.swift")

        precondition(!appState.contains("preferredFormat"))
        precondition(!settingsView.contains("Preferred Format"))
        precondition(!settingsView.contains("FLAC"))
        precondition(!settingsView.contains("preferredFormatBinding"))
        precondition(!contentView.contains("appState.preferredFormat"))
        precondition(!models.contains("case flac"))
        precondition(!trackDetailParser.contains("\"flac\""))
    }

    private static func checkAlbumTopChromeOnlyShowsBackButton() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")

        precondition(source.contains("private let onBack: () -> Void"))
        precondition(source.contains("AlbumTopControls(onBack: onBack)"))
        precondition(!source.contains("ShareLink(item: album.url)"))
        precondition(!source.contains("Label(\"Open in Browser\", systemImage: \"safari\")"))
        precondition(!source.contains("Image(systemName: \"ellipsis\")"))
        precondition(!source.contains(".navigationTitle(viewModel.album?.title"))
        precondition(contentView.contains("onBack: closeAlbum"))
        precondition(!contentView.contains(".toolbar {"))
        precondition(!contentView.contains("Back to Search"))
    }

    private static func checkAlbumDetailUsesSinglePageScroll() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("ScrollView {"))
        precondition(source.contains("LazyVStack(spacing: 0)"))
        precondition(source.contains("ForEach(trackGroups(for: album))"))
        precondition(!source.contains("List(album.tracks)"))
        precondition(!source.contains(".listStyle("))
        precondition(!source.contains(".scrollContentBackground("))
    }

    private static func checkAlbumTopBarAppearsOnlyAfterScrolling() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("private var _scrollOffsetY = State<CGFloat>(initialValue: 0)"))
        precondition(!source.contains("private var _scrollOriginY = State<CGFloat?>(initialValue: nil)"))
        precondition(!source.contains("AlbumScrollOffsetPreferenceKey"))
        precondition(!source.contains("AlbumMetadataBottomPreferenceKey"))
        precondition(source.contains(".modifier(ScrollOffsetTrackingModifier { offsetY in"))
        precondition(source.contains("private struct ScrollOffsetTrackingModifier: ViewModifier"))
        precondition(source.contains("if #available(macOS 15.0, *)"))
        precondition(source.contains(".onScrollGeometryChange(for: CGFloat.self)"))
        precondition(source.contains("geometry.contentOffset.y"))
        precondition(source.contains("ScrollOffsetObserver { offsetY in"))
        precondition(!source.contains("VStack(spacing: 0) {\n                    ScrollOffsetObserver { offsetY in"))
        precondition(source.contains("scrollOffsetY = offsetY"))
        precondition(source.contains("collapsedTopBar(album: album, isVisible: shouldShowCollapsedTopBar)"))
        precondition(source.contains("private var shouldShowCollapsedTopBar: Bool"))
        precondition(source.contains("scrollOffsetY >= AlbumDetailLayout.metadataLineCollapseOffset"))
        precondition(source.contains("private struct ScrollOffsetObserver: NSViewRepresentable"))
        precondition(source.contains("NotificationCenter.default.addObserver"))
        precondition(source.contains("NSView.boundsDidChangeNotification"))
        precondition(source.contains("scrollView.contentView.bounds.origin.y"))
        precondition(source.contains("private var initialOffsetY: CGFloat?"))
        precondition(source.contains("let deltaY = abs(offsetY - (initialOffsetY ?? offsetY))"))
        precondition(source.contains("nearestScrollView(from view: NSView)"))
        precondition(source.contains("findScrollView(in view: NSView)"))
        precondition(source.contains(".opacity(isVisible ? 1 : 0)"))
        precondition(source.contains(".zIndex(AlbumDetailLayout.collapsedTopBarZIndex)"))
        precondition(source.contains("AlbumTopControls(onBack: onBack)"))
    }

    private static func checkAppWindowDoesNotRenderPersistentTitleBar() throws {
        let source = try sourceFile("Sources/KHPlayer/App/KHPlayerApp.swift")

        precondition(source.contains(".windowStyle(.hiddenTitleBar)"))
        precondition(!source.contains(".windowStyle(.titleBar)"))
    }

    private static func checkAppWindowAllowsCompactPlaybackFriendlySize() throws {
        let source = try sourceFile("Sources/KHPlayer/App/KHPlayerApp.swift")

        precondition(source.contains(".frame(minWidth: 880, minHeight: 320)"))
        precondition(!source.contains(".frame(minWidth: 980, minHeight: 640)"))
    }

    private static func checkAlbumDetailStartsAtTopAfterHidingTitleBar() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains(".padding(.top, AlbumDetailLayout.headerTopPadding)"))
        precondition(source.contains("static let headerTopPadding: CGFloat = 54"))
        precondition(!source.contains(".padding(.top, 70)"))
    }

    private static func checkSearchViewUsesFloatingSearchField() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Search/SearchView.swift")

        precondition(source.contains("ZStack(alignment: .top)"))
        precondition(source.contains("floatingSearchHeader"))
        precondition(source.contains("searchResultsTopSpacer"))
        precondition(source.contains("searchResultsBottomSpacer"))
        precondition(source.contains("ForEach(viewModel.results)"))
        precondition(source.contains(".listRowInsets(EdgeInsets())"))
        precondition(source.contains(".listRowSeparator(.hidden)"))
        precondition(source.contains("searchChromeDragArea"))
        precondition(source.contains("SearchChromeDragArea(isHovered: isSearchChromeHoveredBinding)"))
        precondition(source.contains(".glassEffect(.regular, in: Capsule(style: .continuous))"))
        precondition(source.contains("private struct SearchChromeDragArea: NSViewRepresentable"))
        precondition(source.contains("window?.performDrag(with: event)"))
        precondition(source.contains("private var _isSearchChromeHovered = State<Bool>(initialValue: false)"))
        precondition(source.contains("internal static let dragRegionHeight: CGFloat = 72"))
        precondition(source.contains("internal static let headerZIndex: Double = 2"))
        precondition(source.contains("internal static let dragAreaZIndex: Double = 1"))
        precondition(source.contains("internal enum SearchChromeMetrics"))
        precondition(source.contains("internal static let contentTopInset: CGFloat = 72"))
        precondition(source.contains("internal static let contentBottomInset: CGFloat = 92"))
        precondition(source.contains("internal static let headerMaxWidth: CGFloat = 340"))
        precondition(source.contains("internal static let searchFieldMaxWidth: CGFloat = 312"))
        precondition(source.contains("internal static let searchFieldHeight: CGFloat = 34"))
        precondition(source.contains(".strokeBorder(\n                        AdaptiveSystemColors.separator"))
        precondition(!source.contains("internal static let borderOpacity"))
        precondition(!source.contains("internal static let hoverBorderOpacity"))
        precondition(source.contains("Image(systemName: \"magnifyingglass\")"))
        precondition(!source.contains("Image(systemName: \"arrow.right\")"))
        precondition(!source.contains("SearchChromeMetrics.submitButtonSize"))
        precondition(!source.contains(".buttonStyle(.glass)"))
        precondition(!source.contains(".buttonBorderShape(.circle)"))
        precondition(!source.contains(".fill(.ultraThinMaterial)"))
        precondition(!source.contains(".background(.thinMaterial, in: Circle())"))
        precondition(source.contains("TextField(\"Search albums\", text: $viewModel.query)"))
        precondition(source.contains(".onSubmit(performSearch)"))
        precondition(source.contains("ScrollViewReader"))
        precondition(source.contains("HomeAlbumSectionJumpButton(direction: .forward"))
        precondition(source.contains(".scrollIndicators(.hidden)"))
        precondition(source.contains("HomeHorizontalScrollIndicatorHider()"))
        precondition(source.contains("window?.contentView"))
        precondition(source.contains("hideHorizontalScrollers(in:"))
        precondition(source.contains("for subview in view.subviews"))
        precondition(source.contains("scrollView.hasHorizontalScroller = false"))
        precondition(source.contains("scrollTo(targetAlbumID"))
        precondition(source.contains("private var _isHovered = State<Bool>(initialValue: false)"))
        precondition(source.contains(".onHover { isHovered in"))
        precondition(source.contains(".opacity(isHovered ? 1 : 0)"))
        precondition(source.contains("internal static let cardHeight: CGFloat = 268"))
        precondition(source.contains("internal static let jumpButtonWidth: CGFloat = 40"))
        precondition(source.contains("internal static let jumpButtonHeight: CGFloat = 68"))
        precondition(source.contains(".font(.system(size: 26, weight: .medium))"))
        precondition(source.contains(".frame(height: HomeSectionLayout.artworkSize, alignment: .center)"))
        precondition(source.contains(".frame(maxHeight: .infinity, alignment: .top)"))
        precondition(!source.contains(".padding(.top, SearchChromeMetrics.contentTopInset)"))
        precondition(!source.contains("SearchLayout.floatingHeaderHeight"))
        precondition(!source.contains(".stroke(Color.pink"))
        precondition(!source.contains(".textFieldStyle(.roundedBorder)"))
        precondition(!source.contains(".navigationTitle(\"Search\")"))
    }

    private static func checkSearchAndBackControlsKeepReliableHitTargets() throws {
        let searchSource = try sourceFile("Sources/KHPlayer/Features/Search/SearchView.swift")
        let albumSource = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(searchSource.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
        precondition(searchSource.contains("searchHeaderExclusionRect.contains(point) ? nil : self"))
        precondition(searchSource.contains("private var searchHeaderExclusionRect: NSRect"))
        precondition(searchSource.contains("SearchChromeMetrics.headerHeight"))
        precondition(searchSource.contains("internal static let headerHeight = searchFieldHeight + headerVerticalPadding * 2"))

        precondition(albumSource.contains(".contentShape(Circle())"))
        precondition(!albumSource.contains("topControlHitPadding"))
        precondition(!albumSource.contains(".padding(AlbumDetailLayout.topControlHitPadding)"))
    }

    private static func checkSearchClearsResultsInsteadOfOverlayingLoading() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Search/SearchView.swift")
        let viewModel = try sourceFile("Sources/KHPlayer/Features/Search/SearchViewModel.swift")

        precondition(viewModel.contains("isLoading = true\n        results = []"))
        precondition(!source.contains("loadingBannerOverlay"))
        precondition(!source.contains("loadingBannerTopPadding"))
        precondition(!source.contains("loadingBannerZIndex"))
        precondition(!source.contains("""
            VStack(spacing: 0) {
                if viewModel.isLoading, !viewModel.results.isEmpty {
                    loadingBanner
                    Divider()
                }

                content
            }
            """))
    }

    private static func checkSearchStateSurvivesAlbumDetailNavigation() throws {
        let appState = try sourceFile("Sources/KHPlayer/App/AppState.swift")
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")

        precondition(appState.contains("internal let searchViewModel: SearchViewModel"))
        precondition(appState.contains("self.searchViewModel = SearchViewModel(client: client)"))
        precondition(contentView.contains("SearchDetailView(\n                    searchViewModel: appState.searchViewModel,"))
        precondition(!contentView.contains("SearchViewModel(client: appState.client)"))
    }

    private static func checkAlbumDetailOverlaysDestinationInsteadOfReplacingIt() throws {
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")

        precondition(contentView.contains("ZStack {\n            destinationView"))
        precondition(contentView.contains(".opacity(selectedAlbum == nil ? 1 : 0)"))
        precondition(contentView.contains(".allowsHitTesting(selectedAlbum == nil)"))
        precondition(!contentView.contains("""
            if let selectedAlbum {
                albumDetailView(summary: selectedAlbum)
            } else {
                destinationView
            }
            """))
    }

    private static func checkAlbumTopControlsMatchMusicChromePlacement() throws {
        let albumSource = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")

        precondition(contentView.contains(".ignoresSafeArea(.container, edges: .top)"))
        precondition(albumSource.contains(".padding(.top, AlbumDetailLayout.topControlsTopPadding)"))
        precondition(albumSource.contains("static let topControlsTopPadding: CGFloat = 10"))
        precondition(albumSource.contains("static let headerTopPadding: CGFloat = 54"))
        precondition(albumSource.contains(".zIndex(AlbumDetailLayout.topControlsZIndex)"))
    }

    private static func checkCollapsedAlbumTopBarStaysCompact() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("static let topControlButtonSize: CGFloat = 52"))
        precondition(source.contains("static let topControlContentSize: CGFloat = 28"))
        precondition(source.contains("static let collapsedTopBarHeight = topControlButtonSize"))
        precondition(!source.contains("static let collapsedTopBarHeight = topControlButtonSize + 8"))
        precondition(source.contains("VStack(alignment: .leading, spacing: 0)"))
        precondition(source.contains(".font(.subheadline.weight(.semibold))"))
        precondition(source.contains(".font(.caption2)"))
        precondition(source.contains(".frame(height: AlbumDetailLayout.collapsedTopBarHeight, alignment: .center)"))
    }

    private static func checkAlbumDetailUsesSystemAccentColor() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("Color.accentColor"))
        precondition(!source.contains(".pink"))
        precondition(!source.contains("Color.pink"))
    }

    private static func checkSourceUsesAdaptiveSystemColors() throws {
        let sources = try swiftSourceFiles(under: "Sources/KHPlayer")
        let disallowedFragments = [
            "Color.white",
            "Color.black",
            ".white.opacity",
            ".black.opacity",
            ".fill(.white",
            ".stroke(.white",
            "color: .black",
            "AdaptiveSystemColors.separator.opacity(",
            "AdaptiveSystemColors.controlBackground.opacity(",
            "AdaptiveSystemColors.windowBackground.opacity(",
            "AdaptiveSystemColors.subtleSelection.opacity("
        ]

        for path in sources {
            let source = try sourceFile(path)
            for fragment in disallowedFragments {
                precondition(!source.contains(fragment), "\(path) contains \(fragment)")
            }
        }
    }

    private static func checkAlbumTopControlsUseNativeGlassOnly() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")
        let packageSource = try sourceFile("Package.swift")

        precondition(packageSource.contains(".macOS(.v26)"))
        precondition(source.contains(".buttonStyle(.glass)"))
        precondition(source.contains(".buttonBorderShape(.circle)"))
        precondition(!source.contains("ControlGroup {"))
        precondition(!source.contains(".controlGroupStyle(.navigation)"))
        precondition(source.components(separatedBy: "width: AlbumDetailLayout.topControlContentSize").count >= 2)
        precondition(source.components(separatedBy: "height: AlbumDetailLayout.topControlContentSize").count >= 2)
        precondition(!source.contains(".frame(width: AlbumDetailLayout.topControlButtonSize, height: AlbumDetailLayout.topControlButtonSize)"))
        precondition(!source.contains(".controlSize(.large)"))
        precondition(!source.contains("NativeGlassControl"))
        precondition(!source.contains("LegacyAlbumTopControls"))
        precondition(!source.contains("if #available(macOS 26.0, *)"))
        precondition(!source.contains(".background(.regularMaterial)\n            .clipShape(Circle())"))
        precondition(!source.contains(".background(.regularMaterial)\n            .clipShape(Capsule())"))
    }

    private static func checkAlbumActionButtonsStayCompact() throws {
        let source = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")

        precondition(source.contains("static let actionButtonHeight: CGFloat = 36"))
        precondition(source.contains("static let actionPlayButtonMinWidth: CGFloat = 118"))
        precondition(source.contains("static let actionShuffleIconSize: CGFloat = 14"))
        precondition(source.contains(".font(.callout.weight(.semibold))"))
        precondition(source.contains("minWidth: AlbumDetailLayout.actionPlayButtonMinWidth"))
        precondition(source.contains("minHeight: AlbumDetailLayout.actionButtonHeight"))
        precondition(source.contains("width: AlbumDetailLayout.actionButtonHeight"))
        precondition(source.contains("height: AlbumDetailLayout.actionButtonHeight"))
        precondition(source.components(separatedBy: ".contentShape(Circle())").count >= 3)
        precondition(source.contains(".contentShape(Capsule())"))
        precondition(!source.contains(".frame(minWidth: 150, minHeight: 42)"))
        precondition(!source.contains(".frame(width: 42, height: 42)"))
        precondition(!source.contains(".font(.headline.weight(.semibold))"))
    }

    private static func checkFavoritesUseAlbumAndSongCategories() throws {
        let libraryView = try sourceFile("Sources/KHPlayer/Features/Library/LocalLibraryViews.swift")
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")

        precondition(libraryView.contains("internal struct FavoritesView: View"))
        precondition(libraryView.contains("internal enum FavoriteCategory: String, CaseIterable, Identifiable"))
        precondition(libraryView.contains("case albums = \"Albums\""))
        precondition(libraryView.contains("case songs = \"Songs\""))
        precondition(!libraryView.contains("Picker(\"Favorite Category\""))
        precondition(!libraryView.contains(".pickerStyle(.segmented)"))
        precondition(libraryView.contains("try appState.libraryStore.favoriteAlbums()"))
        precondition(libraryView.contains("try appState.libraryStore.favoriteTracks()"))
        precondition(libraryView.contains("private struct FavoriteAlbumRow: View"))
        precondition(libraryView.contains("private struct FavoriteTrackRow: View"))
        precondition(libraryView.contains("No Favorite Albums"))
        precondition(libraryView.contains("No Favorite Songs"))
        precondition(contentView.contains("FavoritesView(\n                    onOpenAlbum: { album in"))
        precondition(contentView.contains("category: favoriteCategory"))
        precondition(contentView.contains("onPlayTrack: { entry, entries in"))
        precondition(contentView.contains("playFavoriteTrack(entry, in: entries)"))
        precondition(contentView.contains("openAlbum(album)"))
        precondition(contentView.contains("private func openAlbum(_ album: AlbumSummary)"))
        precondition(contentView.contains("private func closeAlbum()"))
        precondition(contentView.contains("if destination != selectedDestination {\n                closeAlbum()"))
        precondition(contentView.contains("selectedAlbum = album"))
        precondition(!contentView.contains("""
            FavoritesView(
                    onOpenAlbum: { album in
                        selectedDestination = .search
                        selectedAlbum = album
            """))

        let sidebarView = try sourceFile("Sources/KHPlayer/Features/Shell/SidebarView.swift")

        precondition(sidebarView.contains("case favoriteAlbums"))
        precondition(sidebarView.contains("case favoriteSongs"))
        precondition(sidebarView.contains("DisclosureGroup("))
        precondition(sidebarView.contains("Label(\"Albums\", systemImage: \"square.stack\")"))
        precondition(sidebarView.contains("Label(\"Songs\", systemImage: \"music.note.list\")"))
        precondition(sidebarView.contains(".tag(SidebarDestination.favoriteAlbums)"))
        precondition(sidebarView.contains(".tag(SidebarDestination.favoriteSongs)"))
    }

    private static func checkFavoritesListsUseMusicHoverAndSongTable() throws {
        let libraryView = try sourceFile("Sources/KHPlayer/Features/Library/LocalLibraryViews.swift")

        precondition(libraryView.contains("private var _hoveredFavoriteAlbumID = State<String?>(initialValue: nil)"))
        precondition(libraryView.contains("private var _hoveredFavoriteTrackID = State<String?>(initialValue: nil)"))
        precondition(libraryView.contains("private var _selectedFavoriteTrackID = State<String?>(initialValue: nil)"))
        precondition(libraryView.contains("updateFavoriteAlbumHover(for: album, isHovered: isHovered)"))
        precondition(libraryView.contains("updateFavoriteTrackHover(for: track, isHovered: isHovered)"))
        precondition(libraryView.contains("private struct FavoriteRowSurface<Content: View>: View"))
        precondition(libraryView.contains("private struct FavoriteSongsTable: View"))
        precondition(libraryView.contains("private struct FavoritesHeader: View"))
        precondition(libraryView.contains("private struct FavoriteSearchField: View"))
        precondition(libraryView.contains("private var _favoriteSearchText = State<String>(initialValue: \"\")"))
        precondition(libraryView.contains("private var filteredTracks: [FavoriteTrackEntry]"))
        precondition(libraryView.contains("FavoriteSearchField(text: searchText)"))
        precondition(libraryView.contains(".glassEffect(.regular, in: Capsule(style: .continuous))"))
        precondition(libraryView.contains(".strokeBorder(AdaptiveSystemColors.separator, lineWidth: 1)"))
        precondition(libraryView.contains("AdaptiveSystemColors.shadow.opacity(SearchChromeMetrics.shadowOpacity)"))
        precondition(!libraryView.contains("AdaptiveSystemColors.searchFieldBackground"))
        precondition(!libraryView.contains(".fill(AdaptiveSystemColors.controlBackground)"))
        precondition(libraryView.contains("private struct MusicListHeader: View"))
        precondition(libraryView.contains("title: category == .songs ? \"Songs\" : \"Albums\""))
        precondition(libraryView.contains("countLabel: category == .songs ? songCountLabel : albumCountLabel"))
        precondition(!libraryView.contains("let onRefresh: () -> Void"))
        precondition(!libraryView.contains("onRefresh: loadFavorites"))
        precondition(!libraryView.contains("Refresh Favorites"))
        precondition(libraryView.contains("tracks: filteredTracks"))
        precondition(!libraryView.contains("Table(tracks) {"))
        precondition(libraryView.contains("TableColumn(\"Title\")"))
        precondition(libraryView.contains("TableColumn(\"Album\")"))
        precondition(libraryView.contains("TableColumn(\"Date Added\")"))
        precondition(libraryView.contains("TableColumn(\"Time\")"))
        precondition(libraryView.contains("Table(tracks, selection: selectedTrackID)"))
        precondition(libraryView.contains("private struct FavoriteSongTitleCell: View"))
        precondition(libraryView.contains("private struct FavoriteSongTextCell: View"))
        precondition(libraryView.contains("let currentPlaybackTrackID: String?"))
        precondition(libraryView.contains("isPlaying: currentPlaybackTrackID == entry.id"))
        precondition(!libraryView.contains("@ObservedObject private var playbackEngine: PlaybackEngine"))
        precondition(!libraryView.contains("isPlaying: playbackEngine.currentItem?.track.id == entry.id"))
        precondition(libraryView.contains("let onPlayTrack: (FavoriteTrackEntry) -> Void"))
        precondition(!libraryView.contains("isSelected: selectedTrackID.wrappedValue == entry.id"))
        precondition(!libraryView.contains("let isSelected: Bool"))
        precondition(libraryView.contains("private var leadingIcon: some View"))
        precondition(libraryView.contains("Button {"))
        precondition(libraryView.contains("onPlayTrack(entry)"))
        precondition(libraryView.contains(".disabled(rowIconName.isEmpty)"))
        precondition(libraryView.contains(".help(\"Play Song\")"))
        precondition(libraryView.contains("onPlayTrack(track)"))
        precondition(libraryView.contains("Image(systemName: rowIconName)"))
        precondition(libraryView.contains(".foregroundStyle(.primary)"))
        precondition(!libraryView.contains(".foregroundStyle(Color.accentColor)"))
        precondition(!libraryView.contains(".foregroundStyle(Color.pink)"))
        precondition(libraryView.contains("return \"speaker.wave.2.fill\""))
        precondition(libraryView.contains("return isHovered ? \"play.fill\" : \"\""))
        precondition(libraryView.contains("private struct FavoriteSongsClickMonitor: NSViewRepresentable"))
        precondition(libraryView.contains("FavoriteSongsClickMonitor("))
        precondition(libraryView.contains("NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)"))
        precondition(libraryView.contains("selectedTrackID.wrappedValue = track.id\n\n            guard event.clickCount >= 2 else {"))
        precondition(libraryView.contains("Task { @MainActor [weak self, track] in"))
        precondition(libraryView.contains("private func clickedTrack(for event: NSEvent) -> FavoriteTrackEntry?"))
        precondition(libraryView.contains("let clickedRow = tableView.row(at: pointInTable)"))
        precondition(!libraryView.contains("playSelectedTrack()"))
        precondition(!libraryView.contains(".onTapGesture(count: 2)"))
        precondition(!libraryView.contains("onDoubleClick: {"))
        precondition(!libraryView.contains("onDoubleClick()"))
        precondition(!libraryView.contains("\"ellipsis\""))
        precondition(!libraryView.contains("size: FavoriteListLayout.trackArtworkSize"))
        precondition(!libraryView.contains("width: FavoriteListLayout.trackArtworkSize"))
        precondition(libraryView.contains(".fill(backgroundColor)"))
        precondition(libraryView.contains("AdaptiveSystemColors.rowHoverBackground"))
        precondition(libraryView.contains("AdaptiveSystemColors.rowStripeBackground"))
        precondition(libraryView.contains(".onHover(perform: onHoverChanged)"))
        precondition(libraryView.contains(".padding(.horizontal, 0)"))
        precondition(libraryView.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        precondition(!libraryView.contains(".padding(.horizontal, 0)\n            .padding(.bottom, 120)"))
        precondition(!libraryView.contains("List(albums) { album in"))
        precondition(!libraryView.contains("List(tracks) { track in"))
        precondition(!libraryView.contains("private struct FavoriteSongsTableHeader: View"))
        precondition(!libraryView.contains("private struct FavoriteSongTableRow: View"))

        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")

        precondition(contentView.contains("FavoritesView(\n                    onOpenAlbum: { album in"))
        precondition(contentView.contains("category: favoriteCategory"))
        precondition(contentView.contains("onPlayTrack: { entry, entries in"))
        precondition(contentView.contains("private func playFavoriteTrack(_ entry: FavoriteTrackEntry, in entries: [FavoriteTrackEntry])"))
        precondition(contentView.contains("FavoritePlaybackContext.playbackItems("))
        precondition(contentView.contains("from: entries"))
        precondition(contentView.contains("try await appState.playbackEngine.play(\n                    items: playbackItems"))
    }

    private static func checkAlbumAndTrackFavoriteControlsMatchMusicBehavior() throws {
        let albumSource = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")
        let viewModel = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailViewModel.swift")
        let store = try sourceFile("Sources/KHPlayer/Persistence/LibraryStore.swift")

        precondition(albumSource.contains("onToggleFavorite: viewModel.toggleAlbumFavorite"))
        precondition(albumSource.contains("Image(systemName: isFavorite ? \"checkmark\" : \"plus\")"))
        precondition(albumSource.contains("Add Album to Favorites"))
        precondition(albumSource.contains("Remove Album from Favorites"))
        precondition(albumSource.contains("favoriteTrackIDs.contains(track.id)"))
        precondition(albumSource.contains("private var _hoveredTrackID = State<String?>(initialValue: nil)"))
        precondition(albumSource.contains("private var hoveredTrackID: String?"))
        precondition(albumSource.contains("isHovered: hoveredTrackID == track.id"))
        precondition(albumSource.contains("onHoverChanged: { isHovered in"))
        precondition(albumSource.contains("updateHover(for: track, isHovered: isHovered)"))
        precondition(albumSource.contains("private func updateHover(for track: Track, isHovered: Bool)"))
        precondition(albumSource.contains("hoveredTrackID = track.id"))
        precondition(albumSource.contains("} else if hoveredTrackID == track.id {"))
        precondition(albumSource.contains("withAnimation(.easeOut(duration: TrackColumns.hoverFadeDuration))"))
        precondition(albumSource.contains("hoveredTrackID = nil"))
        precondition(albumSource.contains("let isHovered: Bool"))
        precondition(albumSource.contains("let onHoverChanged: (Bool) -> Void"))
        precondition(!albumSource.contains("private var _isHovered = State<Bool>(initialValue: false)"))
        precondition(albumSource.contains("private var favoriteButton: some View"))
        precondition(albumSource.contains("Image(systemName: isFavorite ? \"star.fill\" : \"star\")"))
        precondition(albumSource.contains("ZStack(alignment: .leading)"))
        precondition(albumSource.contains("TrackRowHoverTrackingView(\n                leadingExtension: TrackColumns.favoriteOutsideInset"))
        precondition(albumSource.contains("onFavoriteClick: onToggleFavorite"))
        precondition(albumSource.contains(".frame(maxWidth: .infinity, minHeight: TrackColumns.rowHitHeight)"))
        precondition(albumSource.contains("private struct TrackRowHoverTrackingView: NSViewRepresentable"))
        precondition(albumSource.contains("let leadingExtension: CGFloat"))
        precondition(albumSource.contains("let onFavoriteClick: () -> Void"))
        precondition(albumSource.contains("var leadingExtension: CGFloat = 0"))
        precondition(albumSource.contains("var onFavoriteClick: (() -> Void)?"))
        precondition(albumSource.contains("private var eventMonitor: Any?"))
        precondition(albumSource.contains("installEventMonitor()"))
        precondition(albumSource.contains("removeEventMonitor()"))
        precondition(albumSource.contains("NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown])"))
        precondition(albumSource.contains("case .mouseMoved:"))
        precondition(albumSource.contains("updateHoverState(with: event)"))
        precondition(albumSource.contains("case .leftMouseDown:"))
        precondition(albumSource.contains("case .leftMouseDown where isFavoriteClickLocation(event):"))
        precondition(albumSource.contains("onFavoriteClick?()"))
        precondition(albumSource.contains("return nil"))
        precondition(albumSource.contains("guard let window, event.window === window else {"))
        precondition(albumSource.contains("rect: trackingRect"))
        precondition(albumSource.contains("trackingRect.contains(point)"))
        precondition(albumSource.contains("private var trackingRect: NSRect"))
        precondition(albumSource.contains("x: -leadingExtension"))
        precondition(albumSource.contains("width: bounds.width + leadingExtension"))
        precondition(albumSource.contains("private var favoriteTrackingRect: NSRect"))
        precondition(albumSource.contains("width: leadingExtension"))
        precondition(albumSource.contains("override func hitTest(_ point: NSPoint) -> NSView? {\n            nil"))
        precondition(albumSource.contains("override func setFrameOrigin(_ newOrigin: NSPoint)"))
        precondition(albumSource.contains("override func setFrameSize(_ newSize: NSSize)"))
        precondition(albumSource.contains("window.mouseLocationOutsideOfEventStream"))
        precondition(albumSource.contains(".mouseMoved"))
        precondition(albumSource.contains("installScrollBoundsObserver()"))
        precondition(albumSource.contains("clipView.postsBoundsChangedNotifications = true"))
        precondition(albumSource.contains("selector: #selector(scrollBoundsDidChange(_:))"))
        precondition(albumSource.contains("NSView.boundsDidChangeNotification"))
        precondition(albumSource.contains("@objc private func scrollBoundsDidChange(_ notification: Notification)"))
        precondition(albumSource.contains("updateHoverState()"))
        precondition(albumSource.contains("private func setHovering(_ isHovering: Bool)"))
        precondition(albumSource.contains("setHovering(true)"))
        precondition(albumSource.contains("setHovering(false)"))
        precondition(albumSource.contains("onHoverChanged?(isHovering)"))
        precondition(albumSource.contains(".opacity(isFavorite || isHovered ? 1 : 0)"))
        precondition(albumSource.contains(".overlay(alignment: .leading)"))
        precondition(albumSource.contains(".offset(x: -TrackColumns.favoriteOutsideInset)"))
        precondition(albumSource.contains("Button(action: onToggleFavorite)"))
        precondition(albumSource.contains(".buttonStyle(.plain)"))
        precondition(albumSource.contains(".frame(width: TrackColumns.favoriteGutter, height: 32)"))
        precondition(albumSource.contains(".background(Color.clear)"))
        precondition(albumSource.contains("private var rowSurface: some View"))
        precondition(albumSource.contains("TrackColumns.rowSeparatorLeadingInset"))
        precondition(albumSource.contains("static let favoriteGutter: CGFloat = 24"))
        precondition(albumSource.contains("static let gutterSpacing: CGFloat = 6"))
        precondition(albumSource.contains("static let rowHitHeight: CGFloat = 42"))
        precondition(albumSource.contains("static let hoverFadeDuration = 0.08"))
        precondition(albumSource.contains("static let favoriteOutsideInset = favoriteGutter + gutterSpacing"))
        precondition(!albumSource.contains(".padding(.leading, -TrackColumns.favoriteOutsideInset)"))
        precondition(!albumSource.contains(".padding(.trailing, -TrackColumns.favoriteOutsideInset)"))
        precondition(albumSource.contains(".contentShape(Rectangle())"))
        precondition(albumSource.contains("static let rowSeparatorLeadingInset = rowHorizontalPadding + number + spacing"))
        precondition(albumSource.contains("leadingPlayHitWidth: TrackColumns.leadingPlayHitWidth"))
        precondition(!albumSource.contains("favoriteHitWidth"))
        precondition(!albumSource.contains("if point.x <= favoriteHitWidth"))
        precondition(!albumSource.contains("favoriteIcon\n\n            numberColumn"))
        precondition(!albumSource.contains("Text(\"\")\n                .frame(width: TrackColumns.favorite"))
        precondition(!albumSource.contains("Color.clear\n                .frame(width: TrackColumns.favoriteGutter)"))
        precondition(!albumSource.contains("TrackColumns.sectionDividerLeadingInset"))
        precondition(albumSource.contains("static let favorite: CGFloat = 24"))
        precondition(viewModel.contains("@Published internal private(set) var isAlbumFavorite = false"))
        precondition(viewModel.contains("@Published internal private(set) var favoriteTrackIDs = Set<String>()"))
        precondition(viewModel.contains("internal func toggleAlbumFavorite()"))
        precondition(viewModel.contains("internal func toggleTrackFavorite(_ track: Track)"))
        precondition(store.contains("func setAlbumFavorite(album: AlbumSummary, isFavorite: Bool) throws"))
        precondition(store.contains("func setTrackFavorite(album: AlbumDetail, track: Track, isFavorite: Bool) throws"))
        precondition(store.contains("func favoriteAlbums() throws -> [FavoriteAlbumEntry]"))
        precondition(store.contains("func favoriteTracks() throws -> [FavoriteTrackEntry]"))
    }

    private static func checkMiniPlayerVolumeControlMatchesMusicBehavior() throws {
        let miniPlayer = try sourceFile("Sources/KHPlayer/Features/Player/MiniPlayerView.swift")
        let engine = try sourceFile("Sources/KHPlayer/Playback/PlaybackEngine.swift")

        precondition(engine.contains("@Published internal var volume: Float"))
        precondition(engine.contains("player?.volume = volume"))
        precondition(engine.contains("newPlayer.volume = volume"))
        precondition(miniPlayer.contains("private var _isVolumeControlPresented = State<Bool>(initialValue: false)"))
        precondition(miniPlayer.contains("MiniPlayerVolumeControl("))
        precondition(miniPlayer.contains("MiniPlayerVolumeFader(volume: volumeBinding)"))
        precondition(miniPlayer.contains("private struct MiniPlayerVolumeFader: View"))
        precondition(miniPlayer.contains("private var _volumeBeforeMute = State<Double>(initialValue: 1)"))
        precondition(miniPlayer.contains(".fill(AdaptiveSystemColors.label)"))
        precondition(miniPlayer.contains("DragGesture(minimumDistance: 0)"))
        precondition(!miniPlayer.contains("Slider(value: volumeBinding"))
        precondition(miniPlayer.contains("private var volumeIcon: some View"))
        precondition(miniPlayer.contains(".symbolRenderingMode(volumeSymbolRenderingMode)"))
        precondition(miniPlayer.contains("private var volumeSymbolRenderingMode: SymbolRenderingMode"))
        precondition(miniPlayer.contains("volume == 0 ? .hierarchical : .monochrome"))
        precondition(miniPlayer.contains("toggleMute()"))
        precondition(miniPlayer.contains("volume == 0 ? \"Unmute\" : \"Mute\""))
        precondition(!miniPlayer.contains("isVolumeControlPresented.toggle()"))
        precondition(miniPlayer.contains(".onHover { isHovered in"))
        precondition(miniPlayer.contains("if isHovered {"))
        precondition(miniPlayer.contains(".glassEffect(.regular.interactive(), in: Capsule(style: .continuous))"))
        precondition(miniPlayer.contains("if isPresented {"))
        precondition(miniPlayer.contains("volumeControlHorizontalPadding"))
        precondition(miniPlayer.contains("volumeControlMinWidth"))
        precondition(miniPlayer.contains(".onHover { isHovered in"))
        precondition(miniPlayer.contains("if !isHovered {"))
        precondition(miniPlayer.contains("isVolumeControlPresented = false"))
    }

    private static func checkMiniPlayerPlaybackFaderMatchesMusicBehavior() throws {
        let miniPlayer = try sourceFile("Sources/KHPlayer/Features/Player/MiniPlayerView.swift")
        let engine = try sourceFile("Sources/KHPlayer/Playback/PlaybackEngine.swift")

        precondition(engine.contains("@Published internal private(set) var elapsedTime: TimeInterval = 0"))
        precondition(engine.contains("@Published internal private(set) var duration: TimeInterval = 0"))
        precondition(engine.contains("internal func seek(to seconds: TimeInterval)"))
        precondition(engine.contains("addPeriodicTimeObserver"))
        precondition(engine.contains("playerTimeObserver"))
        precondition(engine.contains("playerItemDurationObservation"))
        precondition(miniPlayer.contains("MiniPlayerTrackInfo("))
        precondition(miniPlayer.contains("MiniPlayerPlaybackFader("))
        precondition(miniPlayer.contains("MiniPlayerCapsuleFader("))
        precondition(miniPlayer.contains("compactPlaybackTimeline"))
        precondition(miniPlayer.contains("expandedPlaybackTimeline"))
        precondition(miniPlayer.contains("private var _isPlaybackFaderHovered = State<Bool>(initialValue: false)"))
        precondition(miniPlayer.contains("@Namespace private var playbackFaderAnimation"))
        precondition(miniPlayer.contains("matchedGeometryEffect(id: \"playback-fader\""))
        precondition(miniPlayer.contains("onHoverChanged(isHovered)"))
        precondition(miniPlayer.contains("TrackFormatting.durationLabel(elapsedTime)"))
        precondition(miniPlayer.contains("TrackFormatting.durationLabel(duration)"))
        precondition(miniPlayer.contains("onSeek: { progress in"))
        precondition(miniPlayer.contains("engine.seek(to: progress * engine.duration)"))
        precondition(!miniPlayer.contains(".frame(maxWidth: .infinity, minHeight: MiniPlayerLayout.trackInfoHeight, alignment: .center)\n        .contentShape(Rectangle())\n        .onHover"))
        precondition(!miniPlayer.contains("Slider(value: playback"))
    }

    private static func checkMiniPlayerShowsCurrentAlbumArtwork() throws {
        let miniPlayer = try sourceFile("Sources/KHPlayer/Features/Player/MiniPlayerView.swift")

        precondition(miniPlayer.contains("url: currentItem?.album.artworkURL"))
        precondition(miniPlayer.contains("private struct MiniPlayerArtworkView: View"))
        precondition(miniPlayer.contains("AsyncImage(url: url)"))
        precondition(miniPlayer.contains("case .success(let image):"))
        precondition(miniPlayer.contains(".scaledToFill()"))
        precondition(!miniPlayer.contains("Image(systemName: \"music.note\")\n                .font(.system(size: 15, weight: .semibold))\n                .foregroundStyle(.secondary)\n                .frame(width: MiniPlayerLayout.artworkSize, height: MiniPlayerLayout.artworkSize)"))
    }

    private static func checkMiniPlayerArtworkNavigatesToCurrentAlbum() throws {
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")
        let miniPlayer = try sourceFile("Sources/KHPlayer/Features/Player/MiniPlayerView.swift")

        precondition(contentView.contains("onAlbumArtworkPressed: showPlaybackAlbum"))
        precondition(contentView.contains("private func showPlaybackAlbum(_ album: AlbumDetail)"))
        precondition(contentView.contains("guard selectedDestination != .search || selectedAlbum?.id != album.id else"))
        precondition(contentView.contains("selectedDestination = .search"))
        precondition(contentView.contains("selectedAlbum = album.summary"))
        precondition(contentView.contains("private extension AlbumDetail"))
        precondition(contentView.contains("var summary: AlbumSummary"))

        precondition(miniPlayer.contains("let onAlbumArtworkPressed: (AlbumDetail) -> Void"))
        precondition(miniPlayer.contains("onPressed: showCurrentAlbum"))
        precondition(miniPlayer.contains("private func showCurrentAlbum()"))
        precondition(miniPlayer.contains("guard let album = currentItem?.album else"))
        precondition(miniPlayer.contains("onAlbumArtworkPressed(album)"))
        precondition(miniPlayer.contains("isEnabled: currentItem != nil"))
        precondition(miniPlayer.contains("Button(action: onPressed)"))
        precondition(miniPlayer.contains("let isEnabled: Bool"))
        precondition(miniPlayer.contains(".disabled(!isEnabled)"))
        precondition(miniPlayer.contains(".accessibilityLabel(\"Show current album\")"))
        precondition(miniPlayer.contains(".help(\"Show Current Album\")"))
    }

    private static func checkSidebarStaysVisible() throws {
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")
        let sidebarView = try sourceFile("Sources/KHPlayer/Features/Shell/SidebarView.swift")
        let collapseGuard = try sourceFile("Sources/KHPlayer/Features/Shell/SidebarSplitCollapseGuard.swift")

        precondition(contentView.contains("State<NavigationSplitViewVisibility>(initialValue: .all)"))
        precondition(contentView.contains("NavigationSplitView(columnVisibility: sidebarVisibilityBinding)"))
        precondition(contentView.contains(".background(SidebarSplitCollapseGuard(minimumThickness: SidebarLayout.minimumWidth))"))
        precondition(sidebarView.contains(".background(SidebarSplitCollapseGuard(minimumThickness: SidebarLayout.minimumWidth))"))
        precondition(collapseGuard.contains("internal struct SidebarSplitCollapseGuard: NSViewRepresentable"))
        precondition(collapseGuard.contains("item.canCollapse = false"))
        precondition(collapseGuard.contains("item.canCollapseFromWindowResize = false"))
        precondition(collapseGuard.contains("item.minimumThickness = minimumThickness"))
        precondition(collapseGuard.contains("if let item, item.isCollapsed {"))
        precondition(collapseGuard.contains("final class Coordinator"))
        precondition(collapseGuard.contains("private var restoreTimer: Timer?"))
        precondition(collapseGuard.contains("private weak var splitView: NSSplitView?"))
        precondition(collapseGuard.contains("private var minimumThickness: CGFloat = 0"))
        precondition(collapseGuard.contains("Timer.scheduledTimer"))
        precondition(collapseGuard.contains("@objc @MainActor private func restoreCollapsedSidebar()"))
        precondition(collapseGuard.contains("restoreSidebar(item)"))
        precondition(collapseGuard.contains("nearestSplitView(from: view)"))
        precondition(collapseGuard.contains("private func findSplitView(in view: NSView) -> NSSplitView?"))
        precondition(collapseGuard.contains("splitView.setPosition(minimumThickness, ofDividerAt: 0)"))
        precondition(!collapseGuard.contains("maximumThickness"))
        precondition(sidebarView.contains("internal enum SidebarLayout"))
        precondition(sidebarView.contains("internal static let minimumWidth: CGFloat = 180"))
        precondition(sidebarView.contains("internal static let idealWidth: CGFloat = 210"))
        precondition(sidebarView.contains(".navigationSplitViewColumnWidth(min: SidebarLayout.minimumWidth, ideal: SidebarLayout.idealWidth)"))
        precondition(sidebarView.contains(".toolbar(removing: .sidebarToggle)"))
    }

    private static func checkSidebarUsesStableNavigationTopMargin() throws {
        let sidebarView = try sourceFile("Sources/KHPlayer/Features/Shell/SidebarView.swift")

        precondition(sidebarView.contains("internal static let navigationTopContentMargin: CGFloat = 30"))
        precondition(sidebarView.contains(".contentMargins(.top, SidebarLayout.navigationTopContentMargin, for: .scrollContent)"))
    }

    private static func checkHistoryRefreshDoesNotDriveWindowToolbar() throws {
        let libraryView = try sourceFile("Sources/KHPlayer/Features/Library/LocalLibraryViews.swift")

        precondition(!libraryView.contains(".toolbar {\n                Button {"))
        precondition(!libraryView.contains(".overlay(alignment: .topTrailing)"))
        precondition(!libraryView.contains("private var refreshButton: some View"))
        precondition(!libraryView.contains("Label(\"Refresh\", systemImage: \"arrow.clockwise\")"))
        precondition(libraryView.contains("VStack(spacing: 0) {\n            MusicListHeader("))
        precondition(libraryView.contains("title: \"History\""))
        precondition(libraryView.contains("countLabel: historyCountLabel"))
        precondition(libraryView.contains("searchText: historySearchTextBinding"))
        precondition(libraryView.contains("private var _historySearchText = State<String>(initialValue: \"\")"))
        precondition(libraryView.contains("private var filteredEntries: [HistoryEntry]"))
        precondition(libraryView.contains("entry.title.localizedStandardContains(query)"))
        precondition(libraryView.contains("entry.albumID.localizedStandardContains(query)"))
        precondition(libraryView.contains("private var _hoveredHistoryTrackID = State<String?>(initialValue: nil)"))
        precondition(libraryView.contains("private var _selectedHistoryTrackID = State<String?>(initialValue: nil)"))
        precondition(libraryView.contains("HistorySongsTable("))
        precondition(libraryView.contains("entries: filteredEntries"))
        precondition(libraryView.contains("hoveredTrackID: hoveredHistoryTrackID"))
        precondition(libraryView.contains("selectedTrackID: selectedHistoryTrackIDBinding"))
        precondition(libraryView.contains("currentPlaybackTrackID: currentPlaybackTrackID"))
        precondition(libraryView.contains("onPlayTrack: { entry in"))
        precondition(libraryView.contains("onPlayTrack(entry, filteredEntries)"))
        precondition(libraryView.contains("Table(entries, selection: selectedTrackID)"))
        precondition(libraryView.contains(".tableStyle(.inset(alternatesRowBackgrounds: true))"))
        precondition(libraryView.contains("TableColumn(\"Title\")"))
        precondition(libraryView.contains("TableColumn(\"Album\")"))
        precondition(libraryView.contains("TableColumn(\"Last Played\")"))
        precondition(libraryView.contains("private struct HistorySongTitleCell: View"))
        precondition(libraryView.contains("private struct HistorySongTextCell: View"))
        precondition(!libraryView.contains("isSelected: selectedTrackID.wrappedValue == entry.id"))
        precondition(libraryView.contains("private struct HistorySongsClickMonitor: NSViewRepresentable"))
        precondition(libraryView.contains("HistorySongsClickMonitor("))
        precondition(libraryView.contains("isPlaying: currentPlaybackTrackID == entry.id"))
        precondition(libraryView.contains("let onPlayTrack: (HistoryEntry) -> Void"))
        precondition(libraryView.contains("private func clickedTrack(for event: NSEvent) -> HistoryEntry?"))
        precondition(libraryView.contains("Task { @MainActor [weak self, track] in"))
        precondition(libraryView.contains("selectedTrackID.wrappedValue = track.id\n\n            guard event.clickCount >= 2 else {"))
        precondition(!libraryView.contains("List(entries, id: \\.trackID)"))

        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")
        let records = try sourceFile("Sources/KHPlayer/Persistence/Records.swift")
        let store = try sourceFile("Sources/KHPlayer/Persistence/LibraryStore.swift")
        let migrator = try sourceFile("Sources/KHPlayer/Persistence/SchemaMigrator.swift")
        let context = try sourceFile("Sources/KHPlayer/Features/Library/HistoryPlaybackContext.swift")

        precondition(contentView.contains("HistoryView(\n                    onPlayTrack: { entry, entries in"))
        precondition(contentView.contains("playHistoryTrack(entry, in: entries)"))
        precondition(contentView.contains("private func playHistoryTrack(_ entry: HistoryEntry, in entries: [HistoryEntry])"))
        precondition(contentView.contains("HistoryPlaybackContext.playbackItems("))
        precondition(contentView.contains("This history song is missing playback metadata."))
        precondition(contentView.contains("private func playLegacyHistoryTrack(_ entry: HistoryEntry)"))
        precondition(contentView.contains("private func loadHistoryAlbum(for entry: HistoryEntry, appState: AppState) async throws -> AlbumDetail"))
        precondition(contentView.contains("legacyHistoryAlbumURL(albumID: entry.albumID)"))
        precondition(records.contains("var albumTitle: String?"))
        precondition(records.contains("var detailURL: URL?"))
        precondition(records.contains("var albumURL: URL?"))
        precondition(records.contains("var duration: TimeInterval?"))
        precondition(store.contains("func recordPlay(album: AlbumDetail, track: Track) throws"))
        precondition(migrator.contains("registerMigration(\"v5\")"))
        precondition(context.contains("internal enum HistoryPlaybackContext"))
        precondition(context.contains("from entries: [HistoryEntry]"))
        precondition(context.contains("guard let albumURL = entry.albumURL, let detailURL = entry.detailURL else"))
    }

    private static func checkAlbumTracksUseDoubleClickAndPlayingHighlight() throws {
        let albumSource = try sourceFile("Sources/KHPlayer/Features/Album/AlbumDetailView.swift")
        let contentView = try sourceFile("Sources/KHPlayer/Features/Shell/ContentView.swift")
        let engine = try sourceFile("Sources/KHPlayer/Playback/PlaybackEngine.swift")

        precondition(contentView.contains("playbackEngine: appState.playbackEngine"))
        precondition(albumSource.contains("@ObservedObject private var playbackEngine: PlaybackEngine"))
        precondition(albumSource.contains("State<String?>(initialValue: nil)"))
        precondition(albumSource.contains("State<Bool>(initialValue: false)"))
        precondition(albumSource.contains("private var selectedTrackID: String?"))
        precondition(albumSource.contains("private var isLeadingPlayPressed: Bool"))
        precondition(albumSource.contains("let isPlaying: Bool"))
        precondition(albumSource.contains("let isSelected: Bool"))
        precondition(albumSource.contains("isPlaying: isPlaying(track: track, in: album)"))
        precondition(albumSource.contains("isSelected: selectedTrackID == track.id"))
        precondition(albumSource.contains("private func isPlaying(track: Track, in album: AlbumDetail) -> Bool"))
        precondition(albumSource.contains("TrackRowInteractionView("))
        precondition(albumSource.contains("private struct TrackRowInteractionView: NSViewRepresentable"))
        precondition(albumSource.contains("override func mouseDown(with event: NSEvent)"))
        precondition(albumSource.contains("let isLeadingPlayEnabled: Bool"))
        precondition(albumSource.contains("isLeadingPlayEnabled: !isPlaying"))
        precondition(albumSource.contains("let leadingPlayHitWidth: CGFloat"))
        precondition(albumSource.contains("let onLeadingPlayPress: () -> Void"))
        precondition(albumSource.contains("if isLeadingPlayEnabled && point.x <= leadingPlayHitWidth"))
        precondition(albumSource.contains("onLeadingPlayPress?()"))
        precondition(albumSource.contains("DispatchQueue.main.asyncAfter"))
        precondition(albumSource.contains("isLeadingPlayPressed ?"))
        precondition(albumSource.contains(".animation(.easeOut(duration: 0.12), value: isLeadingPlayPressed)"))
        precondition(albumSource.contains("static let number: CGFloat = 22"))
        precondition(albumSource.contains("static let rowHorizontalPadding: CGFloat = 4"))
        precondition(albumSource.contains("static let rowSeparatorLeadingInset = rowHorizontalPadding + number + spacing"))
        precondition(albumSource.contains("if event.clickCount >= 2"))
        precondition(!albumSource.contains(".onHover { isHovered in\n            self.isHovered = isHovered"))
        precondition(albumSource.contains("onHoverChanged(isHovered)"))
        precondition(!albumSource.contains("if !isHovered {\n                self.isFavoriteButtonHovered = false"))
        precondition(albumSource.contains(".onDisappear {"))
        precondition(albumSource.contains("onHoverChanged(false)"))
        precondition(albumSource.contains("selectedTrackID = track.id"))
        precondition(albumSource.contains("Image(systemName: \"waveform\")"))
        precondition(albumSource.contains("Image(systemName: \"play.fill\")"))
        precondition(albumSource.contains("isSelected ? Color.accentColor :"))
        precondition(albumSource.contains("isHovered && !isPlaying"))
        precondition(albumSource.contains("AdaptiveSystemColors.rowHoverBackground"))
        precondition(!albumSource.contains("let onHover: (Bool) -> Void"))
        precondition(!albumSource.contains("isFavoriteButtonHovered"))
        precondition(!albumSource.contains("updateFavoriteHover(with: event)"))
        precondition(!albumSource.contains(".onTapGesture(count: 2)"))
        precondition(!albumSource.contains(".onTapGesture {\n            onSelect()"))
        precondition(!albumSource.contains("Button {\n                onPlay(album, track)"))
        precondition(engine.contains("try await self.next()"))
        precondition(!engine.contains("self.isPlaying = false\n            }"))
    }

    private static func sourceFile(_ path: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    private static func swiftSourceFiles(under path: String) throws -> [String] {
        let rootURL = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map(\.relativePath)
    }
}
