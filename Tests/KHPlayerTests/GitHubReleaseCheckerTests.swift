import Foundation

@testable import KHPlayer

// Compile-only helpers for update-checking behavior. XCTest and Swift Testing are
// unavailable or incomplete in the local CommandLineTools environment.
internal struct GitHubReleaseCheckerTests {
    internal func semanticVersionsCompareNumericSegments() {
        precondition(AppVersion("0.1.10") > AppVersion("0.1.2"))
        precondition(AppVersion("v1.0") == AppVersion("1.0.0"))
        precondition(AppVersion("1.2.0-beta") == AppVersion("1.2.0"))
    }

    internal func releaseAvailabilityDetectsNewerLatestRelease() throws {
        let currentVersion = AppVersion("0.1.2")
        let latestRelease = GitHubRelease(
            tagName: "v0.1.3",
            name: "v0.1.3",
            htmlURL: URL(string: "https://github.com/ImBada/khinsider-player-mac/releases/tag/v0.1.3")!
        )

        let availability = UpdateAvailability(
            currentVersion: currentVersion,
            latestRelease: latestRelease
        )

        precondition(availability.isUpdateAvailable)
        precondition(availability.releaseURL == latestRelease.htmlURL)
    }
}
