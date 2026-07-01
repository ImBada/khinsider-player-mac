import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. These helper methods document
// the intended request-builder checks without importing a test framework.
internal struct KHRequestBuilderTests {
    internal func albumSearchUsesExpectedQueryItems() throws {
        let url = try KHRequestBuilder.searchURL(
            query: " persona 5\n",
            type: .album,
            sort: .relevance
        )

        precondition(
            url.absoluteString == "https://downloads.khinsider.com/search?search=persona%205&type=album&sort=relevance"
        )
    }

    internal func songSearchUsesExpectedQueryItems() throws {
        let url = try KHRequestBuilder.searchURL(query: "persona", type: .song, sort: .name)

        precondition(
            url.absoluteString == "https://downloads.khinsider.com/search?search=persona&type=song&sort=name"
        )
    }

    internal func emptySearchQueryThrowsInvalidURL() throws {
        do {
            _ = try KHRequestBuilder.searchURL(query: " \n\t ", type: .album, sort: .relevance)
            preconditionFailure("Expected KHError.invalidURL for an empty search query.")
        } catch KHError.invalidURL(let message) {
            precondition(message == "empty search query")
        }
    }
}
