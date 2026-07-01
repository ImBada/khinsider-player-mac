import SwiftUI

@testable import KHPlayer

// Compile-only helpers for the persistent mini-player surface. XCTest and
// Swift Testing are unavailable in the local CommandLineTools environment.
internal struct MiniPlayerCompileTests {
    @MainActor
    internal func miniPlayerViewReadsPlaybackFromEnvironmentAppState() throws {
        let state = try AppState()

        _ = MiniPlayerView()
            .environmentObject(state)
    }

    @MainActor
    internal func miniPlayerNextActionCanGuardAgainstReplacedPlaybackEngine() async throws {
        let state = try AppState()
        let originalEngine = state.playbackEngine

        try await state.setCacheLimitBytes(512 * 1024 * 1024)

        precondition(!MiniPlayerEngineGuard.isCurrent(originalEngine, in: state))
        precondition(MiniPlayerEngineGuard.isCurrent(state.playbackEngine, in: state))
    }
}
