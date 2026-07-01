import Foundation

@testable import KHPlayer

// Compile-only placeholder for the CommandLineTools environment, where XCTest
// and Swift Testing are unavailable or incomplete. These helper methods document
// the intended KHClient request-gate checks without importing a test framework.
internal struct KHClientCompileTests {
    internal func requestGateAcceptsDefaultHTMLSpacing() async throws {
        let gate = RequestGate(minimumDelay: .milliseconds(500))

        try await gate.waitForTurn()
        try await gate.waitForTurn()
    }
}
