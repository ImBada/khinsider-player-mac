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
            emptyState
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
        Group {
            if trimmedQuery.isEmpty {
                ContentUnavailableView(
                    "Search KHInsider Albums",
                    systemImage: "magnifyingglass",
                    description: Text("Album results will appear here.")
                )
            } else {
                ContentUnavailableView(
                    "No Albums Found",
                    systemImage: "music.note.list",
                    description: Text("Try a different album title.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    internal static let contentBottomInset: CGFloat = 92
    internal static let headerTopPadding: CGFloat = 12
    internal static let outerHorizontalPadding: CGFloat = 28
    internal static let headerHorizontalPadding: CGFloat = 14
    internal static let headerVerticalPadding: CGFloat = 4
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
    }
}

private struct AlbumResultRow: View {
    let album: AlbumSummary

    private var _isHovered = State<Bool>(initialValue: false)

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
