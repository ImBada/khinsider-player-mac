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
            .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

internal struct AppContentView: View {
    internal let appState: AppState

    internal var body: some View {
        ContentView()
            .environment(\.appState, appState)
            .environmentObject(appState)
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
