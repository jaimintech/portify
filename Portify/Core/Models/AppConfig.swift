import Foundation

/// Application configuration persisted to ~/.config/portify/config.json
struct AppConfig: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var scanInterval: TimeInterval
    var launchAtLogin: Bool
    var showInDock: Bool
    var portRangeMin: UInt16
    var portRangeMax: UInt16
    var overrides: [PortOverride]
    var sortOrder: SortOrder
    var showNotifications: Bool
    var globalHotkeyEnabled: Bool

    enum SortOrder: String, Codable, Sendable, CaseIterable {
        case port
        case name
        case type
        case recent
    }

    static let `default` = AppConfig(
        schemaVersion: Constants.currentSchemaVersion,
        scanInterval: Constants.defaultScanInterval,
        launchAtLogin: false,
        showInDock: false,
        portRangeMin: 1,
        portRangeMax: 65535,
        overrides: [],
        sortOrder: .port,
        showNotifications: false,
        globalHotkeyEnabled: false
    )
}
