import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("scanInterval") private var scanInterval: Double = Constants.defaultScanInterval
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("showNotifications") private var showNotifications = false

    var body: some View {
        Form {
            Section("Scanning") {
                HStack {
                    Text("Refresh interval")
                    Spacer()
                    Stepper(
                        "\(Int(scanInterval))s",
                        value: $scanInterval,
                        in: Constants.minScanInterval...Constants.maxScanInterval,
                        step: 1
                    )
                    .frame(width: 100)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        try? LaunchAtLogin.setEnabled(newValue)
                    }

                Toggle("Show in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
            }

            Section("Notifications") {
                Toggle("Show notifications for server start/stop", isOn: $showNotifications)
            }

            Section("Config File") {
                HStack {
                    Text(ConfigStore.defaultConfigURL().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Reveal in Finder") {
                        let url = ConfigStore.defaultConfigURL()
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
