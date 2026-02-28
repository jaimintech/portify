import PortifyCore
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

                Button(action: { viewModel.groupByProject.toggle() }) {
                    Image(systemName: viewModel.groupByProject ? "folder.fill" : "folder")
                }
                .buttonStyle(.borderless)
                .help(viewModel.groupByProject ? "Ungroup servers" : "Group by project")
                .accessibilityLabel("Toggle project grouping")

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
            } else if viewModel.groupByProject {
                groupedList
            } else {
                flatList
            }

            // Error banner
            if let error = viewModel.killError {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") { viewModel.killError = nil }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                .padding(8)
            }

            // Degraded mode indicator
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

            // Overflow indicator
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

    private var flatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.servers) { server in
                    ServerRowView(server: server, viewModel: viewModel)
                }
            }
        }
    }

    private var groupedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.groups) { group in
                    // Group header
                    HStack {
                        Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(group.projectName)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(group.servers.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.toggleGroup(group) }

                    if !group.isCollapsed {
                        ForEach(group.servers) { server in
                            ServerRowView(server: server, viewModel: viewModel)
                                .padding(.leading, 8)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
    }
}
