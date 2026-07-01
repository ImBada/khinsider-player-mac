import SwiftUI

@testable import KHPlayer

// Compile-only helpers for the native search screen. XCTest and Swift Testing
// are unavailable in the local CommandLineTools environment.
internal struct SearchViewCompileTests {
    @MainActor
    internal func searchViewModelExposesInitialSearchState() {
        let model = SearchViewModel(client: KHClient())

        precondition(model.query.isEmpty)
        precondition(model.results.isEmpty)
        precondition(!model.isLoading)
        precondition(model.errorMessage == nil)
    }

    @MainActor
    internal func searchViewAcceptsOwnedViewModelAndAlbumOpenHandler() {
        let model = SearchViewModel(client: KHClient())

        _ = SearchView(viewModel: model) { album in
            precondition(!album.title.isEmpty)
        }
    }

    @MainActor
    internal func searchChromeUsesFloatingLiquidGlassLayout() {
        precondition(SearchChromeMetrics.contentTopInset >= 64)
        precondition(SearchChromeMetrics.headerTopPadding <= 18)
        precondition(SearchChromeMetrics.searchFieldHeight <= 36)
        precondition(SearchChromeMetrics.searchFieldMaxWidth <= 380)
        precondition(SearchChromeMetrics.headerMaxWidth <= 460)
        precondition(SearchChromeMetrics.borderWidth == 1)
    }

    @MainActor
    internal func searchResultRowsUseTrackLikeHoverTreatment() {
        precondition(SearchResultRowMetrics.cornerRadius == 7)
    }
}
