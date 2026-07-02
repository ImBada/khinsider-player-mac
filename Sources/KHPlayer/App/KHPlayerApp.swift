import SwiftUI

@main
@MainActor
struct KHPlayerApp: App {
    @StateObject private var launchState = AppLaunchState()

    var body: some Scene {
        WindowGroup {
            Group {
                if let appState = launchState.appState {
                    AppContentView(appState: appState)
                } else {
                    LaunchStateView(
                        message: launchState.errorMessage ?? "Local app state is unavailable.",
                        retry: launchState.retry
                    )
                }
            }
            .frame(minWidth: 880, minHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            if let appState = launchState.appState {
                PlaybackCommands(appState: appState)
            }
        }
    }
}

internal struct PlaybackCommands: Commands {
    @ObservedObject private var playbackEngine: PlaybackEngine

    internal init(appState: AppState) {
        self.playbackEngine = appState.playbackEngine
    }

    internal var body: some Commands {
        CommandMenu("Playback") {
            Button("Play/Pause") {
                playbackEngine.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(playbackEngine.currentItem == nil)
        }
    }
}

internal struct AppContentView: View {
    internal let appState: AppState

    internal var body: some View {
        ContentView()
            .environment(\.appState, appState)
            .environmentObject(appState)
            .task {
                try? await Task.sleep(for: .seconds(1))
                await appState.checkForUpdatesIfNeeded()
            }
    }
}

@MainActor
private final class AppLaunchState: ObservableObject {
    @Published private(set) var appState: AppState?
    @Published private(set) var errorMessage: String?

    init() {
        retry()
    }

    func retry() {
        do {
            appState = try AppState()
            errorMessage = nil
        } catch {
            appState = nil
            errorMessage = error.localizedDescription
        }
    }
}
