import PortifyCore
import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("portRangeMin") private var portRangeMin: Int = 1
    @AppStorage("portRangeMax") private var portRangeMax: Int = 65535
    @AppStorage("globalHotkeyEnabled") private var globalHotkeyEnabled = false
    @AppStorage("additionalProcessNames") private var additionalProcessNames = ""
    @AppStorage("ignoredPorts") private var ignoredPorts = ""

    @State private var showingHotkeyPermission = false

    var body: some View {
        Form {
            Section("Port Range") {
                HStack {
                    Text("Minimum port")
                    Spacer()
                    TextField("Min", value: $portRangeMin, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Maximum port")
                    Spacer()
                    TextField("Max", value: $portRangeMax, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Detection") {
                VStack(alignment: .leading) {
                    Text("Additional process names to detect")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., my-server, custom-app (comma-separated)", text: $additionalProcessNames)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Ignored ports")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., 22, 80, 443 (comma-separated)", text: $ignoredPorts)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Global Hotkey") {
                Toggle("Enable global hotkey (Option+P)", isOn: $globalHotkeyEnabled)
                    .onChange(of: globalHotkeyEnabled) { _, newValue in
                        if newValue {
                            checkAccessibilityPermission()
                        }
                    }

                if globalHotkeyEnabled {
                    Text("Press Option+P from anywhere to toggle Portify")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Reset All Settings to Defaults", role: .destructive) {
                    resetDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Accessibility Permission Required", isPresented: $showingHotkeyPermission) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
            Button("Cancel", role: .cancel) {
                globalHotkeyEnabled = false
            }
        } message: {
            Text("Portify needs Accessibility permission to detect the global hotkey. Please add Portify in System Settings > Privacy & Security > Accessibility.")
        }
    }

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            showingHotkeyPermission = true
        }
    }

    private func resetDefaults() {
        portRangeMin = 1
        portRangeMax = 65535
        globalHotkeyEnabled = false
        additionalProcessNames = ""
        ignoredPorts = ""
    }
}
