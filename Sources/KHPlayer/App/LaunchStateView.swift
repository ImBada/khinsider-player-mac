import SwiftUI

internal struct LaunchStateView: View {
    private let message: String
    private let retry: () -> Void

    internal init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    internal var body: some View {
        VStack(spacing: 16) {
            Text("KHInsider Player could not start")
                .font(.headline)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            Button("Retry", action: retry)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
