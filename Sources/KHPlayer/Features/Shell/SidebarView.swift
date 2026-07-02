import SwiftUI

internal enum SidebarLayout {
    internal static let minimumWidth: CGFloat = 180
    internal static let idealWidth: CGFloat = 210
    internal static let navigationTopContentMargin: CGFloat = 30
}

internal enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case search
    case favorites
    case favoriteAlbums
    case favoriteSongs
    case history
    case settings

    internal var id: Self {
        self
    }

    internal var title: String {
        switch self {
        case .search:
            "Search"
        case .favorites:
            "Favorites"
        case .favoriteAlbums:
            "Albums"
        case .favoriteSongs:
            "Songs"
        case .history:
            "History"
        case .settings:
            "Settings"
        }
    }

    internal var systemImage: String {
        switch self {
        case .search:
            "magnifyingglass"
        case .favorites:
            "star"
        case .favoriteAlbums:
            "square.stack"
        case .favoriteSongs:
            "music.note.list"
        case .history:
            "clock"
        case .settings:
            "gearshape"
        }
    }
}

internal struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    @Binding private var selection: SidebarDestination?
    private var _isFavoritesExpanded = State<Bool>(initialValue: true)

    internal init(selection: Binding<SidebarDestination?>) {
        _selection = selection
    }

    private var isFavoritesExpanded: Binding<Bool> {
        _isFavoritesExpanded.projectedValue
    }

    internal var body: some View {
        List(selection: $selection) {
            Label(SidebarDestination.search.title, systemImage: SidebarDestination.search.systemImage)
                .tag(SidebarDestination.search)

            DisclosureGroup(isExpanded: isFavoritesExpanded) {
                Label("Albums", systemImage: "square.stack")
                    .tag(SidebarDestination.favoriteAlbums)

                Label("Songs", systemImage: "music.note.list")
                    .tag(SidebarDestination.favoriteSongs)
            } label: {
                Button {
                    selection = .favoriteAlbums
                } label: {
                    Label(SidebarDestination.favorites.title, systemImage: SidebarDestination.favorites.systemImage)
                }
                .buttonStyle(.plain)
            }

            Label(SidebarDestination.history.title, systemImage: SidebarDestination.history.systemImage)
                .tag(SidebarDestination.history)

            Label(SidebarDestination.settings.title, systemImage: SidebarDestination.settings.systemImage)
                .tag(SidebarDestination.settings)
        }
        .navigationTitle("KHInsider")
        .contentMargins(.top, SidebarLayout.navigationTopContentMargin, for: .scrollContent)
        .navigationSplitViewColumnWidth(min: SidebarLayout.minimumWidth, ideal: SidebarLayout.idealWidth)
        .background(SidebarSplitCollapseGuard(minimumThickness: SidebarLayout.minimumWidth))
        .toolbar(removing: .sidebarToggle)
        .overlay(alignment: .bottomTrailing) {
            if appState.updateAvailability != nil {
                SidebarUpdateButton {
                    appState.checkForUpdates()
                }
                .padding(.trailing, 14)
                .padding(.bottom, 14)
            }
        }
    }
}

private struct SidebarUpdateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Update", systemImage: "arrow.down.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color.accentColor, in: Capsule(style: .continuous))
        .shadow(color: AdaptiveSystemColors.shadow.opacity(0.18), radius: 8, x: 0, y: 3)
        .help("Check for and install app updates")
    }
}
