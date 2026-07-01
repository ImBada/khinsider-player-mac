import SwiftUI

@testable import KHPlayer

// Compile-only helpers for the local settings and library views. XCTest and
// Swift Testing are unavailable in the local CommandLineTools environment.
internal struct SettingsLibraryCompileTests {
    @MainActor
    internal func sidebarDestinationsExposeLocalLibraryRoutes() {
        precondition(SidebarDestination.search.title == "Search")
        precondition(SidebarDestination.favorites.systemImage == "star")
        precondition(SidebarDestination.history.systemImage == "clock")
        precondition(SidebarDestination.settings.title == "Settings")
        precondition(SidebarDestination.allCases.count >= 4)

        _ = SidebarView(selection: .constant(.search))
    }

    @MainActor
    internal func settingsViewReadsObservableAppState() throws {
        let state = try AppState()

        _ = SettingsView()
            .environmentObject(state)
    }

    @MainActor
    internal func localLibraryViewsReadObservableAppState() throws {
        let state = try AppState()

        _ = HistoryView()
            .environmentObject(state)
        _ = FavoritesView()
            .environmentObject(state)
    }
}
