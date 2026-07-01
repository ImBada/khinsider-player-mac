import Foundation

internal final class HomeSectionsCache {
    private let directory: URL
    private let fileURL: URL
    private let freshnessInterval: TimeInterval
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    internal init(
        directory: URL,
        freshnessInterval: TimeInterval = 24 * 60 * 60,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("home-sections.json", isDirectory: false)
        self.freshnessInterval = freshnessInterval
        self.fileManager = fileManager
    }

    internal static func appCache() throws -> HomeSectionsCache {
        let cachesURL = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return HomeSectionsCache(
            directory: cachesURL
                .appendingPathComponent("com.bada.khinsider-player-mac", isDirectory: true)
                .appendingPathComponent("HomeSections", isDirectory: true)
        )
    }

    internal func load(now: Date = Date()) throws -> HomeSectionsSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(HomeSectionsSnapshot.self, from: data)
        guard isComplete(snapshot) else {
            return nil
        }

        guard now.timeIntervalSince(snapshot.fetchedAt) < freshnessInterval else {
            return nil
        }

        return snapshot
    }

    internal func save(_ snapshot: HomeSectionsSnapshot) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private func isComplete(_ snapshot: HomeSectionsSnapshot) -> Bool {
        HomeSectionSource.allCases.allSatisfy { source in
            snapshot.sections.contains { section in
                section.source == source && !section.albums.isEmpty
            }
        }
    }
}
