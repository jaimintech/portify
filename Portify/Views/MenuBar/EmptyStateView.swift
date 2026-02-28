import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No Dev Servers Detected")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Start a dev server and it will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No dev servers detected. Start a dev server and it will appear here.")
    }
}
