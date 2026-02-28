import SwiftUI

struct ServerRowView: View {
    let server: DevServer
    @ObservedObject var viewModel: ServerListViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: server.processType.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.projectName)
                    .font(.body)
                    .lineLimit(1)
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
            Button("Kill Process", role: .destructive) {
                Task { await viewModel.killServer(server) }
            }
        }
        .help("PID: \(server.pid) — \(server.processPath)")
    }

    private func openInBrowser() {
        if let url = server.url {
            NSWorkspace.shared.open(url)
        }
    }
}
