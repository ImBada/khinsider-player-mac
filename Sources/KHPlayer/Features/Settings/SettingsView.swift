import SwiftUI

internal struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var _cacheLimitErrorMessage = State<String?>(initialValue: nil)
    private var _isUpdatingCacheLimit = State<Bool>(initialValue: false)

    private static let cacheLimitOptionsBytes: [Int64] = [64, 128, 256, 512]
        .map { Int64($0) * 1024 * 1024 }

    internal init() {}

    internal var body: some View {
        Form {
            Section("Cache") {
                Picker("Limit", selection: cacheLimitBinding) {
                    ForEach(Self.cacheLimitOptionsBytes, id: \.self) { limitBytes in
                        Text(cacheLimitTitle(for: limitBytes))
                            .tag(limitBytes)
                    }
                }
                .disabled(isUpdatingCacheLimit)

                if isUpdatingCacheLimit {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 460, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .navigationTitle("Settings")
        .alert(
            "Cache Limit Failed",
            isPresented: isCacheLimitErrorPresented
        ) {
            Button("OK", role: .cancel) {
                cacheLimitErrorMessage = nil
            }
        } message: {
            Text(cacheLimitErrorMessage ?? "The cache limit could not be changed.")
        }
    }

    private var cacheLimitBinding: Binding<Int64> {
        Binding {
            appState.cacheLimitBytes
        } set: { limitBytes in
            updateCacheLimit(to: limitBytes)
        }
    }

    private var cacheLimitErrorMessage: String? {
        get {
            _cacheLimitErrorMessage.wrappedValue
        }
        nonmutating set {
            _cacheLimitErrorMessage.wrappedValue = newValue
        }
    }

    private var isUpdatingCacheLimit: Bool {
        get {
            _isUpdatingCacheLimit.wrappedValue
        }
        nonmutating set {
            _isUpdatingCacheLimit.wrappedValue = newValue
        }
    }

    private var isCacheLimitErrorPresented: Binding<Bool> {
        Binding {
            cacheLimitErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                cacheLimitErrorMessage = nil
            }
        }
    }

    private func updateCacheLimit(to limitBytes: Int64) {
        guard limitBytes != appState.cacheLimitBytes else {
            return
        }

        cacheLimitErrorMessage = nil
        isUpdatingCacheLimit = true

        Task { @MainActor in
            do {
                try await appState.setCacheLimitBytes(limitBytes)
            } catch {
                cacheLimitErrorMessage = error.localizedDescription
            }

            isUpdatingCacheLimit = false
        }
    }

    private func cacheLimitTitle(for limitBytes: Int64) -> String {
        "\(limitBytes / 1024 / 1024) MB"
    }
}
