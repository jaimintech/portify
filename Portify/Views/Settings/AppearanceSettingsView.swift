import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("sortOrder") private var sortOrder: AppConfig.SortOrder = .port
    @AppStorage("showProcessType") private var showProcessType = true
    @AppStorage("showPortNumber") private var showPortNumber = true

    var body: some View {
        Form {
            Section("Sort Order") {
                Picker("Sort servers by", selection: $sortOrder) {
                    Text("Port number").tag(AppConfig.SortOrder.port)
                    Text("Project name").tag(AppConfig.SortOrder.name)
                    Text("Process type").tag(AppConfig.SortOrder.type)
                    Text("Most recent").tag(AppConfig.SortOrder.recent)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Display") {
                Toggle("Show process type label", isOn: $showProcessType)
                Toggle("Show port number", isOn: $showPortNumber)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

