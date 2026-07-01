import SwiftUI

private struct AppStateEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

internal extension EnvironmentValues {
    var appState: AppState? {
        get {
            self[AppStateEnvironmentKey.self]
        }
        set {
            self[AppStateEnvironmentKey.self] = newValue
        }
    }
}
