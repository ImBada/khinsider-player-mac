import Combine
import Foundation

@MainActor
internal final class SearchViewModel: ObservableObject {
    @Published internal var query = ""
    @Published internal private(set) var results: [AlbumSummary] = []
    @Published internal private(set) var isLoading = false
    @Published internal private(set) var errorMessage: String?

    private let client: KHClient
    private var searchGeneration = 0

    internal init(client: KHClient) {
        self.client = client
    }

    internal func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration

        errorMessage = nil

        guard !trimmedQuery.isEmpty else {
            results = []
            isLoading = false
            return
        }

        isLoading = true
        results = []

        do {
            let url = try KHRequestBuilder.searchURL(
                query: trimmedQuery,
                type: .album,
                sort: .relevance
            )
            let html = try await client.html(from: url)
            let albums = try SearchResultsParser.parse(html: html)

            guard generation == searchGeneration else {
                return
            }

            results = albums
            errorMessage = nil
            isLoading = false
        } catch {
            guard generation == searchGeneration else {
                return
            }

            results = []
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
