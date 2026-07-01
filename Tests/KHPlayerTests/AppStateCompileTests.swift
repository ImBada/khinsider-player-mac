import SwiftUI

@testable import KHPlayer

// Compile-only helpers for the app-level dependency container. XCTest and Swift
// Testing are unavailable in the local CommandLineTools environment.
internal struct AppStateCompileTests {
    @MainActor
    internal func appStateProvidesDefaultApplicationDependencies() throws {
        let state = try AppState()

        precondition(state.cacheLimitBytes == 256 * 1024 * 1024)

        _ = state.client
        _ = state.streamResolver
        _ = state.libraryStore
        _ = state.playbackEngine
    }

    @MainActor
    internal func appStateOwnsSearchViewModelAcrossDetailNavigation() throws {
        let state = try AppState()

        precondition(state.searchViewModel === state.searchViewModel)
    }

    @MainActor
    internal func changingCacheLimitReplacesPlaybackEngine() async throws {
        let state = try AppState()
        let originalEngine = state.playbackEngine

        try await state.setCacheLimitBytes(512 * 1024 * 1024)

        precondition(state.cacheLimitBytes == 512 * 1024 * 1024)
        precondition(state.playbackEngine !== originalEngine)
    }

    @MainActor
    internal func invalidCacheLimitLeavesPlaybackEngineUnchanged() async throws {
        let state = try AppState()
        let originalEngine = state.playbackEngine

        do {
            try await state.setCacheLimitBytes(1)
            preconditionFailure("Expected KHError.cacheLimitTooSmall for a one-byte cache limit.")
        } catch KHError.cacheLimitTooSmall {
        }

        precondition(state.cacheLimitBytes == 256 * 1024 * 1024)
        precondition(state.playbackEngine === originalEngine)
    }

    @MainActor
    internal func contentViewAcceptsOptionalAppStateEnvironmentValue() throws {
        let state = try AppState()

        _ = ContentView()
            .environment(\.appState, state)
    }

    @MainActor
    internal func appContentViewInjectsObservableAppState() throws {
        let state = try AppState()

        _ = AppContentView(appState: state)
        _ = ContentView()
            .environmentObject(state)
            .environment(\.appState, state)
    }

    @MainActor
    internal func launchStateViewAcceptsRetryAction() {
        _ = LaunchStateView(message: "Failed to initialize AppState") {}
    }
}
