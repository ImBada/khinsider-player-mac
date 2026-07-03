import AppKit
import SwiftUI

internal struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel

    private let onOpenAlbum: (AlbumSummary) -> Void
    private var _isSearchChromeHovered = State<Bool>(initialValue: false)

    internal init(
        viewModel: @autoclosure @escaping () -> SearchViewModel,
        onOpenAlbum: @escaping (AlbumSummary) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onOpenAlbum = onOpenAlbum
    }

    internal var body: some View {
        ZStack(alignment: .top) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            searchChromeBlurBackground
            searchChromeDragArea
            floatingSearchHeader
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.loadHomeSectionsIfNeeded()
        }
    }

    private var trimmedQuery: String {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchChromeHovered: Bool {
        get {
            _isSearchChromeHovered.wrappedValue
        }
        nonmutating set {
            _isSearchChromeHovered.wrappedValue = newValue
        }
    }

    private var isSearchChromeHoveredBinding: Binding<Bool> {
        _isSearchChromeHovered.projectedValue
    }

    private var searchChromeBlurBackground: some View {
        Rectangle()
            .fill(Color.clear)
            .glassEffect(.regular, in: Rectangle())
            .overlay {
                AdaptiveSystemColors.chromeOverlayBackground
            }
            .frame(height: SearchChromeMetrics.dragRegionHeight)
            .frame(maxWidth: .infinity, alignment: .top)
            .opacity(isSearchChromeHovered ? 1 : 0)
            .animation(
                .easeInOut(duration: SearchChromeMetrics.blurAnimationDuration),
                value: isSearchChromeHovered
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(SearchChromeMetrics.blurBandZIndex)
    }

    private var floatingSearchHeader: some View {
        searchBar
            .padding(.horizontal, SearchChromeMetrics.headerHorizontalPadding)
            .padding(.vertical, SearchChromeMetrics.headerVerticalPadding)
            .frame(maxWidth: SearchChromeMetrics.headerMaxWidth)
            .glassEffect(.regular, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        AdaptiveSystemColors.separator,
                        lineWidth: SearchChromeMetrics.borderWidth
                    )
            }
            .shadow(
                color: AdaptiveSystemColors.shadow.opacity(
                    isSearchChromeHovered
                        ? SearchChromeMetrics.hoverShadowOpacity
                        : SearchChromeMetrics.shadowOpacity
                ),
                radius: isSearchChromeHovered
                    ? SearchChromeMetrics.hoverShadowRadius
                    : SearchChromeMetrics.shadowRadius,
                y: SearchChromeMetrics.shadowYOffset
            )
            .padding(.top, SearchChromeMetrics.headerTopPadding)
            .padding(.horizontal, SearchChromeMetrics.outerHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(SearchChromeMetrics.headerZIndex)
    }

    private var searchChromeDragArea: some View {
        SearchChromeDragArea(isHovered: isSearchChromeHoveredBinding)
            .frame(height: SearchChromeMetrics.dragRegionHeight)
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .zIndex(SearchChromeMetrics.dragAreaZIndex)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search albums", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .onSubmit(performSearch)
        }
        .frame(
            maxWidth: SearchChromeMetrics.searchFieldMaxWidth,
            minHeight: SearchChromeMetrics.searchFieldHeight
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.results.isEmpty {
            loadingState
        } else if let errorMessage = viewModel.errorMessage {
            errorState(message: errorMessage)
        } else if viewModel.results.isEmpty {
            if trimmedQuery.isEmpty {
                homeContent
            } else {
                emptyState
            }
        } else {
            resultsList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("Searching")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Search Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(action: performSearch) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .disabled(trimmedQuery.isEmpty)
        }
        .textSelection(.enabled)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Albums Found",
            systemImage: "music.note.list",
            description: Text("Try a different album title.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HomeSectionLayout.sectionSpacing) {
                Color.clear
                    .frame(height: SearchChromeMetrics.contentTopInset)
                    .background {
                        SearchScrollIndicatorInsetsSetter(
                            scrollerTop: SearchChromeMetrics.scrollIndicatorTopInset
                        )
                    }
                    .accessibilityHidden(true)

                if viewModel.homeSections.isEmpty {
                    homeLoadingOrError
                        .frame(maxWidth: .infinity, minHeight: HomeSectionLayout.emptyStateMinHeight)
                } else {
                    ForEach(viewModel.homeSections) { section in
                        HomeAlbumSectionRow(section: section, onOpenAlbum: onOpenAlbum)
                    }
                }
            }
            .padding(.horizontal, HomeSectionLayout.horizontalPadding)
            .padding(.bottom, HomeSectionLayout.bottomPadding)
        }
        .scrollIndicators(.visible)
    }

    @ViewBuilder
    private var homeLoadingOrError: some View {
        if viewModel.isLoadingHomeSections {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)

                Text("Loading Home")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if let homeErrorMessage = viewModel.homeErrorMessage {
            ContentUnavailableView {
                Label("Home Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(homeErrorMessage)
            } actions: {
                Button {
                    Task {
                        await viewModel.loadHomeSectionsIfNeeded(forceRefresh: true)
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
            }
            .textSelection(.enabled)
        } else {
            EmptyView()
        }
    }

    private var resultsList: some View {
        List {
            searchResultsTopSpacer

            ForEach(viewModel.results) { album in
                Button {
                    onOpenAlbum(album)
                } label: {
                    AlbumResultRow(album: album)
                }
                .buttonStyle(.plain)
            }

            searchResultsBottomSpacer
        }
        .listStyle(.inset)
    }

    private var searchResultsTopSpacer: some View {
        Color.clear
            .frame(height: SearchChromeMetrics.contentTopInset)
            .background {
                SearchScrollIndicatorInsetsSetter(
                    scrollerTop: SearchChromeMetrics.scrollIndicatorTopInset
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private var searchResultsBottomSpacer: some View {
        Color.clear
            .frame(height: SearchChromeMetrics.contentBottomInset)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private func performSearch() {
        Task {
            await viewModel.search()
        }
    }
}

internal enum SearchChromeMetrics {
    internal static let contentTopInset: CGFloat = 72
    internal static let scrollIndicatorTopInset = contentTopInset - headerTopPadding
    internal static let contentBottomInset: CGFloat = 92
    internal static let headerTopPadding: CGFloat = 12
    internal static let outerHorizontalPadding: CGFloat = 28
    internal static let headerHorizontalPadding: CGFloat = 14
    internal static let headerVerticalPadding: CGFloat = 4
    internal static let headerHeight = searchFieldHeight + headerVerticalPadding * 2
    internal static let headerMaxWidth: CGFloat = 340
    internal static let searchFieldMaxWidth: CGFloat = 312
    internal static let searchFieldHeight: CGFloat = 34
    internal static let borderWidth: CGFloat = 1
    internal static let shadowOpacity: CGFloat = 0.22
    internal static let shadowRadius: CGFloat = 18
    internal static let shadowYOffset: CGFloat = 8
    internal static let hoverShadowOpacity: CGFloat = 0.28
    internal static let hoverShadowRadius: CGFloat = 22
    internal static let dragRegionHeight: CGFloat = 72
    internal static let blurAnimationDuration: Double = 0.12
    internal static let blurBandZIndex: Double = 0.5
    internal static let headerZIndex: Double = 2
    internal static let dragAreaZIndex: Double = 1
}

internal enum SearchResultRowMetrics {
    internal static let cornerRadius: CGFloat = 7
}

internal enum HomeSectionLayout {
    internal static let horizontalPadding: CGFloat = 32
    internal static let sectionSpacing: CGFloat = 34
    internal static let headerBottomPadding: CGFloat = 12
    internal static let cardSpacing: CGFloat = 24
    internal static let artworkSize: CGFloat = 174
    internal static let artworkCornerRadius: CGFloat = 8
    internal static let cardWidth: CGFloat = 174
    internal static let cardHeight: CGFloat = 268
    internal static let jumpButtonWidth: CGFloat = 40
    internal static let jumpButtonHeight: CGFloat = 68
    internal static let jumpButtonHorizontalOffset: CGFloat = 12
    internal static let jumpStride: Int = 5
    internal static let bottomPadding: CGFloat = 92
    internal static let emptyStateMinHeight: CGFloat = 280
}

private struct SearchScrollIndicatorInsetsSetter: NSViewRepresentable {
    let scrollerTop: CGFloat

    func makeNSView(context: Context) -> ScrollIndicatorInsetsView {
        ScrollIndicatorInsetsView(scrollerTop: scrollerTop)
    }

    func updateNSView(_ nsView: ScrollIndicatorInsetsView, context: Context) {
        nsView.scrollerTop = scrollerTop
        nsView.updateScrollIndicatorInsets()
    }

    final class ScrollIndicatorInsetsView: NSView {
        var scrollerTop: CGFloat
        private weak var observedScrollView: NSScrollView?
        private var isApplyingInsets = false

        init(scrollerTop: CGFloat) {
            self.scrollerTop = scrollerTop
            super.init(frame: .zero)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if window == nil {
                detachScrollViewFrameObserver()
            }

            updateScrollIndicatorInsets()
        }

        override func layout() {
            super.layout()
            updateScrollIndicatorInsets()
        }

        func updateScrollIndicatorInsets() {
            if !applyScrollIndicatorInsetNow() {
                DispatchQueue.main.async { [weak self] in
                    self?.applyScrollIndicatorInsetNow()
                }
            }
        }

        @discardableResult
        private func applyScrollIndicatorInsetNow() -> Bool {
            guard !isApplyingInsets else {
                return true
            }

            guard let searchScrollView = enclosingScrollView else {
                return false
            }

            isApplyingInsets = true
            defer {
                isApplyingInsets = false
            }

            attachScrollViewFrameObserver(to: searchScrollView)
            TopInsetScroller.install(on: searchScrollView, topInset: scrollerTop)
            searchScrollView.tile()
            return true
        }

        private func attachScrollViewFrameObserver(to searchScrollView: NSScrollView) {
            guard observedScrollView !== searchScrollView else {
                return
            }

            detachScrollViewFrameObserver()
            observedScrollView = searchScrollView
            searchScrollView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewFrameDidChange(_:)),
                name: NSView.frameDidChangeNotification,
                object: searchScrollView
            )
        }

        @objc private func scrollViewFrameDidChange(_ notification: Notification) {
            applyScrollIndicatorInsetNow()
        }

        private func detachScrollViewFrameObserver() {
            guard let observedScrollView else {
                return
            }

            NotificationCenter.default.removeObserver(
                self,
                name: NSView.frameDidChangeNotification,
                object: observedScrollView
            )
            self.observedScrollView = nil
        }
    }
}

private struct SearchChromeDragArea: NSViewRepresentable {
    @Binding var isHovered: Bool

    func makeNSView(context: Context) -> DragAreaView {
        let view = DragAreaView(frame: .zero)
        view.onHoverChanged = { isHovered in
            self.isHovered = isHovered
        }
        return view
    }

    func updateNSView(_ nsView: DragAreaView, context: Context) {
        nsView.onHoverChanged = { isHovered in
            self.isHovered = isHovered
        }
    }

    final class DragAreaView: NSView {
        var onHoverChanged: ((Bool) -> Void)?

        private var trackingArea: NSTrackingArea?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard bounds.contains(point) else {
                return nil
            }

            return searchHeaderExclusionRect.contains(point) ? nil : self
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea {
                removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                .activeInActiveApp,
                .inVisibleRect,
                .mouseEnteredAndExited
            ]
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: options,
                owner: self,
                userInfo: nil
            )

            addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
        }

        override func mouseEntered(with event: NSEvent) {
            onHoverChanged?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHoverChanged?(false)
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        private var searchHeaderExclusionRect: NSRect {
            let width = min(bounds.width, SearchChromeMetrics.headerMaxWidth)
            let originX = (bounds.width - width) / 2
            let originY = max(
                0,
                bounds.height - SearchChromeMetrics.headerTopPadding - SearchChromeMetrics.headerHeight
            )

            return NSRect(
                x: originX,
                y: originY,
                width: width,
                height: SearchChromeMetrics.headerHeight
            )
        }
    }
}

private struct AlbumResultRow: View {
    let album: AlbumSummary

    private var _isHovered = State<Bool>(initialValue: false)

    fileprivate init(album: AlbumSummary) {
        self.album = album
    }

    private var isHovered: Bool {
        get {
            _isHovered.wrappedValue
        }
        nonmutating set {
            _isHovered.wrappedValue = newValue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)
        }
        .padding(.vertical, 5)
        .frame(minHeight: 58)
        .background {
            RoundedRectangle(cornerRadius: SearchResultRowMetrics.cornerRadius, style: .continuous)
                .fill(hoverBackground)
        }
        .contentShape(Rectangle())
        .onHover { isHovered in
            self.isHovered = isHovered
        }
        .onDisappear {
            self.isHovered = false
        }
    }

    private var hoverBackground: Color {
        isHovered ? AdaptiveSystemColors.rowHoverBackground : Color.clear
    }

    private var artwork: some View {
        AsyncImage(url: album.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty, .failure:
                artworkPlaceholder
            @unknown default:
                artworkPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.quaternary)

            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var metadata: String {
        var parts: [String] = []

        if let year = album.year {
            parts.append(String(year))
        }

        if let albumType = album.albumType, !albumType.isEmpty {
            parts.append(albumType)
        }

        if !album.platforms.isEmpty {
            parts.append(album.platforms.joined(separator: ", "))
        }

        return parts.joined(separator: " - ")
    }
}

private struct HomeAlbumSectionRow: View {
    let section: HomeSection
    let onOpenAlbum: (AlbumSummary) -> Void

    private var _scrollIndex = State<Int>(initialValue: 0)
    private var _isHovered = State<Bool>(initialValue: false)

    fileprivate init(section: HomeSection, onOpenAlbum: @escaping (AlbumSummary) -> Void) {
        self.section = section
        self.onOpenAlbum = onOpenAlbum
    }

    private var scrollIndex: Int {
        get {
            _scrollIndex.wrappedValue
        }
        nonmutating set {
            _scrollIndex.wrappedValue = newValue
        }
    }

    private var isHovered: Bool {
        get {
            _isHovered.wrappedValue
        }
        nonmutating set {
            _isHovered.wrappedValue = newValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.source.title)
                .font(.title3.weight(.bold))
                .padding(.bottom, HomeSectionLayout.headerBottomPadding)

            ScrollViewReader { proxy in
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: HomeSectionLayout.cardSpacing) {
                            ForEach(displayedAlbums) { album in
                                Button {
                                    onOpenAlbum(album)
                                } label: {
                                    HomeAlbumCard(album: album)
                                }
                                .buttonStyle(.plain)
                                .id(album.id)
                            }
                        }
                        .padding(.trailing, HomeSectionLayout.horizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    .background {
                        HomeHorizontalScrollIndicatorHider()
                    }

                    jumpControls(proxy: proxy)
                }
            }
            .frame(height: HomeSectionLayout.cardHeight)
        }
        .onHover { isHovered in
            self.isHovered = isHovered
        }
        .onDisappear {
            isHovered = false
        }
    }

    private var displayedAlbums: [AlbumSummary] {
        Array(section.albums.prefix(20))
    }

    @ViewBuilder
    private func jumpControls(proxy: ScrollViewProxy) -> some View {
        if displayedAlbums.count > 1 {
            HStack {
                if scrollIndex > 0 {
                    HomeAlbumSectionJumpButton(direction: .backward) {
                        jump(by: -HomeSectionLayout.jumpStride, proxy: proxy)
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 0)

                if scrollIndex < displayedAlbums.count - 1 {
                    HomeAlbumSectionJumpButton(direction: .forward) {
                        jump(by: HomeSectionLayout.jumpStride, proxy: proxy)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, HomeSectionLayout.jumpButtonHorizontalOffset)
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.16), value: scrollIndex)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .allowsHitTesting(true)
            .frame(height: HomeSectionLayout.artworkSize, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func jump(by stride: Int, proxy: ScrollViewProxy) {
        guard !displayedAlbums.isEmpty else {
            return
        }

        let targetIndex = min(max(scrollIndex + stride, 0), displayedAlbums.count - 1)
        let targetAlbumID = displayedAlbums[targetIndex].id
        scrollIndex = targetIndex

        withAnimation(.easeInOut(duration: 0.28)) {
            proxy.scrollTo(targetAlbumID, anchor: targetIndex == 0 ? .leading : .center)
        }
    }
}

private enum HomeAlbumSectionJumpDirection {
    case backward
    case forward

    var systemImage: String {
        switch self {
        case .backward:
            "chevron.left"
        case .forward:
            "chevron.right"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .backward:
            "Previous albums"
        case .forward:
            "Next albums"
        }
    }
}

private struct HomeAlbumSectionJumpButton: View {
    let direction: HomeAlbumSectionJumpDirection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AdaptiveSystemColors.selectedText)
                .frame(
                    width: HomeSectionLayout.jumpButtonWidth,
                    height: HomeSectionLayout.jumpButtonHeight
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(AdaptiveSystemColors.subtleSelection), in: Capsule(style: .continuous))
        .shadow(color: AdaptiveSystemColors.shadow.opacity(0.26), radius: 14, y: 6)
        .accessibilityLabel(direction.accessibilityLabel)
    }
}

private struct HomeHorizontalScrollIndicatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> IndicatorHiderView {
        IndicatorHiderView(frame: .zero)
    }

    func updateNSView(_ nsView: IndicatorHiderView, context: Context) {
        nsView.hideHorizontalScrollers()
    }

    final class IndicatorHiderView: NSView {
        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            hideHorizontalScrollers()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            hideHorizontalScrollers()
        }

        override func layout() {
            super.layout()
            hideHorizontalScrollers()
        }

        func hideHorizontalScrollers() {
            DispatchQueue.main.async { [weak self] in
                self?.hideHorizontalScrollersNow()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.hideHorizontalScrollersNow()
            }
        }

        private func hideHorizontalScrollersNow() {
            guard let rootView = window?.contentView else {
                return
            }

            hideHorizontalScrollers(in: rootView)
        }

        private func hideHorizontalScrollers(in view: NSView) {
            if let scrollView = view as? NSScrollView {
                scrollView.hasHorizontalScroller = false
                scrollView.horizontalScroller = nil
                scrollView.autohidesScrollers = true
            }

            for subview in view.subviews {
                hideHorizontalScrollers(in: subview)
            }
        }
    }
}

private struct HomeAlbumCard: View {
    let album: AlbumSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            artwork

            Text(album.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !metadata.isEmpty {
                Text(metadata)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: HomeSectionLayout.cardWidth, height: HomeSectionLayout.cardHeight, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var artwork: some View {
        AsyncImage(url: album.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty, .failure:
                artworkPlaceholder
            @unknown default:
                artworkPlaceholder
            }
        }
        .frame(width: HomeSectionLayout.artworkSize, height: HomeSectionLayout.artworkSize)
        .background(.quaternary)
        .clipShape(
            RoundedRectangle(
                cornerRadius: HomeSectionLayout.artworkCornerRadius,
                style: .continuous
            )
        )
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: HomeSectionLayout.artworkCornerRadius,
                style: .continuous
            )
            .fill(.quaternary)

            Image(systemName: "music.note")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var metadata: String {
        var parts: [String] = []

        if let year = album.year {
            parts.append(String(year))
        }

        if !album.platforms.isEmpty {
            parts.append(album.platforms.prefix(2).joined(separator: ", "))
        } else if let albumType = album.albumType, !albumType.isEmpty {
            parts.append(albumType)
        }

        return parts.joined(separator: " - ")
    }
}
