import Combine
import Foundation

@MainActor
internal final class SearchViewModel: ObservableObject {
    @Published internal var query = ""
    @Published internal private(set) var results: [AlbumSummary] = []
    @Published internal private(set) var isLoading = false
    @Published internal private(set) var homeSections: [HomeSection] = []
    @Published internal private(set) var isLoadingHomeSections = false
    @Published internal private(set) var homeErrorMessage: String?
    @Published internal private(set) var errorMessage: String?

    private let client: KHClient
    private let homeSectionsCache: HomeSectionsCache?
    private var searchGeneration = 0
    private var didRequestHomeSections = false

    internal init(client: KHClient, homeSectionsCache: HomeSectionsCache? = try? HomeSectionsCache.appCache()) {
        self.client = client
        self.homeSectionsCache = homeSectionsCache
    }

    internal func loadHomeSectionsIfNeeded(forceRefresh: Bool = false) async {
        guard forceRefresh || !didRequestHomeSections else {
            return
        }

        didRequestHomeSections = true
        homeErrorMessage = nil

        if !forceRefresh, let cachedSnapshot = try? homeSectionsCache?.load() {
            homeSections = orderedSections(cachedSnapshot.sections)
            return
        }

        isLoadingHomeSections = true

        var loadedSections: [HomeSection] = []
        var lastError: Error?

        for source in HomeSectionSource.allCases {
            do {
                let albums = try await albums(for: source)
                guard !albums.isEmpty else {
                    continue
                }

                loadedSections.append(HomeSection(source: source, albums: albums))
                homeSections = orderedSections(loadedSections)
            } catch is CancellationError {
                isLoadingHomeSections = false
                return
            } catch {
                lastError = error
            }
        }

        if loadedSections.count == HomeSectionSource.allCases.count {
            let snapshot = HomeSectionsSnapshot(
                fetchedAt: Date(),
                sections: orderedSections(loadedSections)
            )
            try? homeSectionsCache?.save(snapshot)
            homeSections = snapshot.sections
            homeErrorMessage = nil
        } else if !loadedSections.isEmpty {
            homeSections = orderedSections(loadedSections)
            homeErrorMessage = lastError?.localizedDescription
        } else if let lastError {
            homeErrorMessage = lastError.localizedDescription
        }

        isLoadingHomeSections = false
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

    private func orderedSections(_ sections: [HomeSection]) -> [HomeSection] {
        HomeSectionSource.allCases.compactMap { source in
            sections.first { $0.source == source }
        }
    }

    private func albums(for source: HomeSectionSource) async throws -> [AlbumSummary] {
        do {
            let html = try await client.html(from: source.url)
            let albums = try HomeSectionParser.parse(html: html, source: source, limit: 20)
            if !albums.isEmpty {
                return albums
            }
        } catch {
            let markdown = try await client.html(from: source.readerURL)
            return HomeSectionParser.parseReaderMarkdown(markdown, limit: 20)
        }

        let markdown = try await client.html(from: source.readerURL)
        return HomeSectionParser.parseReaderMarkdown(markdown, limit: 20)
    }
}
