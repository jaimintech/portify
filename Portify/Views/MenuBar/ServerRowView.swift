import PortifyCore
import SwiftUI

struct ServerRowView: View {
    let server: DevServer
    @ObservedObject var viewModel: ServerListViewModel
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 8) {
            // Pin indicator
            if viewModel.isPinned(server) {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .frame(width: 10)
            } else {
                Color.clear.frame(width: 10)
            }

            // Process type icon
            Image(systemName: server.processType.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Label", text: $editText, onCommit: {
                        viewModel.setCustomLabel(editText.isEmpty ? nil : editText, for: server.port)
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.body)
                } else {
                    Text(viewModel.displayName(for: server))
                        .font(.body)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            editText = viewModel.displayName(for: server)
                            isEditing = true
                        }
                }

                HStack(spacing: 4) {
                    Text(server.portString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(server.processType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { openInBrowser() }) {
                Image(systemName: "globe")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Open \(server.projectName) in browser")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { openInBrowser() }
        .contextMenu {
            Button("Copy URL") {
                if let url = server.url {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }
            Button("Open in Browser") { openInBrowser() }

            Divider()

            Button(viewModel.isPinned(server) ? "Unpin" : "Pin to Top") {
                viewModel.togglePin(port: server.port)
            }

            Button("Rename...") {
                editText = viewModel.displayName(for: server)
                isEditing = true
            }

            if viewModel.customLabels[server.port] != nil {
                Button("Clear Custom Label") {
                    viewModel.setCustomLabel(nil, for: server.port)
                }
            }

            Divider()

            Button("Kill Process", role: .destructive) {
                Task { await viewModel.killServer(server) }
            }

            if viewModel.killError != nil {
                Button("Force Kill (SIGKILL)", role: .destructive) {
                    viewModel.forceKillServer(server)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Port \(server.port), project \(viewModel.displayName(for: server)), \(server.processType.displayName) server. Actions available.")
        .help("PID: \(server.pid) — \(server.processPath)")
    }

    private func openInBrowser() {
        if let url = server.url {
            NSWorkspace.shared.open(url)
        }
    }
}
