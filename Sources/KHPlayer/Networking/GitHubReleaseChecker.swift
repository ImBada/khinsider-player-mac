import Foundation

internal struct AppVersion: Comparable, Sendable {
    private let components: [Int]

    internal init(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedValue = trimmedValue.hasPrefix("v")
            ? String(trimmedValue.dropFirst())
            : trimmedValue
        let releaseValue = normalizedValue.split(separator: "-", maxSplits: 1).first ?? ""

        components = releaseValue
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    internal static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.compare(to: rhs) == .orderedSame
    }

    internal static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.compare(to: rhs) == .orderedAscending
    }

    private func compare(to other: AppVersion) -> ComparisonResult {
        let count = max(components.count, other.components.count)

        for index in 0..<count {
            let lhsComponent = components.indices.contains(index) ? components[index] : 0
            let rhsComponent = other.components.indices.contains(index) ? other.components[index] : 0

            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent ? .orderedAscending : .orderedDescending
            }
        }

        return .orderedSame
    }
}

internal struct GitHubRelease: Equatable, Sendable {
    internal let tagName: String
    internal let name: String?
    internal let htmlURL: URL
}

internal struct UpdateAvailability: Equatable, Sendable {
    internal let currentVersion: AppVersion
    internal let latestRelease: GitHubRelease

    internal var isUpdateAvailable: Bool {
        currentVersion < AppVersion(latestRelease.tagName)
    }

    internal var releaseURL: URL {
        latestRelease.htmlURL
    }
}

internal final class GitHubReleaseChecker: Sendable {
    private struct LatestReleaseResponse: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: URL

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
        }
    }

    private let latestReleaseURL: URL
    private let session: URLSession

    internal init(
        latestReleaseURL: URL = URL(string: "https://api.github.com/repos/ImBada/khinsider-player-mac/releases/latest")!,
        session: URLSession = .shared
    ) {
        self.latestReleaseURL = latestReleaseURL
        self.session = session
    }

    internal func latestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("KHInsiderPlayerMac/0.1 (+https://github.com/ImBada/khinsider-player-mac)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KHError.networkStatus(-1)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw KHError.networkStatus(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(LatestReleaseResponse.self, from: data)
        return GitHubRelease(
            tagName: release.tagName,
            name: release.name,
            htmlURL: release.htmlURL
        )
    }

    internal func updateAvailability(currentVersion: String) async throws -> UpdateAvailability {
        UpdateAvailability(
            currentVersion: AppVersion(currentVersion),
            latestRelease: try await latestRelease()
        )
    }
}
