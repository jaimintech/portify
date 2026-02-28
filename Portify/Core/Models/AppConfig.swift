import Foundation

/// Application configuration persisted to ~/.config/portify/config.json
public struct AppConfig: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var scanInterval: TimeInterval
    public var launchAtLogin: Bool
    public var showInDock: Bool
    public var portRangeMin: UInt16
    public var portRangeMax: UInt16
    public var overrides: [PortOverride]
    public var sortOrder: SortOrder
    public var showNotifications: Bool
    public var globalHotkeyEnabled: Bool

    public enum SortOrder: String, Codable, Sendable, CaseIterable {
        case port
        case name
        case type
        case recent
    }

    public static let `default` = AppConfig(
        schemaVersion: CoreConstants.currentSchemaVersion,
        scanInterval: CoreConstants.defaultScanInterval,
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
