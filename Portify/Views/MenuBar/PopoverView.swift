import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ServerListViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Portify")
                    .font(.headline)
                Spacer()
                Button(action: { Task { await viewModel.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Refresh server list")

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Server list
            if viewModel.servers.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.servers) { server in
                            ServerRowView(server: server, viewModel: viewModel)
                        }
                    }
                }
            }

            // Footer
            if viewModel.isDegraded {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Scanner running in degraded mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            if viewModel.totalCount > Constants.maxDisplayedServers {
                Divider()
                Text("and \(viewModel.totalCount - Constants.maxDisplayedServers) more...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(4)
            }
        }
        .frame(width: 320, height: 400)
    }
}
