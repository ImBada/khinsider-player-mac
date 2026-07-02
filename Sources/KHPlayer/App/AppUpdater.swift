import Combine
import Sparkle

@MainActor
internal final class AppUpdater: ObservableObject {
    @Published internal private(set) var canCheckForUpdates = false

    private let updaterController: SPUStandardUpdaterController

    internal init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    internal func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }
}
