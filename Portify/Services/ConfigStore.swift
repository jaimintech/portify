import Foundation
import OSLog

/// Actor-based configuration store with file watching and migration support.
actor ConfigStore {
    private var config: AppConfig
    private let configURL: URL
    private var watcher: (any ConfigWatching)?
    private var onChange: (@Sendable (AppConfig) -> Void)?

    var currentConfig: AppConfig { config }

    init(configURL: URL? = nil) {
        let url = configURL ?? Self.defaultConfigURL()
        self.configURL = url
        self.config = .default

        // Try to load existing config
        if let loaded = Self.loadConfig(from: url) {
            self.config = loaded
        }
    }

    func update(_ transform: (inout AppConfig) -> Void) async throws {
        transform(&config)
        try await save()
    }

    func startWatching(watcher: any ConfigWatching, onChange: @escaping @Sendable (AppConfig) -> Void) {
        self.watcher = watcher
        self.onChange = onChange

        try? watcher.startWatching { [configURL] in
            if let loaded = Self.loadConfig(from: configURL) {
                Task { @Sendable in
                    onChange(loaded)
                }
            }
        }
    }

    func stopWatching() {
        watcher?.stopWatching()
        watcher = nil
    }

    private func save() async throws {
        let directory = configURL.deletingLastPathComponent()

        // Create directory if needed
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Atomic write via temp file + rename
        let tempURL = directory.appendingPathComponent(".config.json.tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        try data.write(to: tempURL, options: .atomic)

        // Set file permissions to 0600
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: tempURL.path
        )

        // Rename into place
        _ = try FileManager.default.replaceItemAt(configURL, withItemAt: tempURL)

        Logger.config.info("Config saved to \(self.configURL.path)")
    }

    static func defaultConfigURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(Constants.configDirectory)
            .appendingPathComponent(Constants.configFileName)
    }

    private static func loadConfig(from url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else {
            Logger.config.info("No config file found at \(url.path), using defaults")
            return nil
        }

        do {
            var config = try JSONDecoder().decode(AppConfig.self, from: data)

            if config.schemaVersion > Constants.currentSchemaVersion {
                Logger.config.warning("Config schema version \(config.schemaVersion) is newer than supported (\(Constants.currentSchemaVersion)). Using defaults.")
                return nil
            }

            // Run migrations if needed
            if config.schemaVersion < Constants.currentSchemaVersion {
                config = migrate(config, from: config.schemaVersion)
            }

            return config
        } catch {
            Logger.config.error("Failed to parse config: \(error.localizedDescription). Using defaults.")
            return nil
        }
    }

    private static func migrate(_ config: AppConfig, from version: Int) -> AppConfig {
        var config = config
        // Migration registry — add cases as schema evolves
        // Currently at version 1, no migrations needed
        config.schemaVersion = Constants.currentSchemaVersion
        Logger.config.info("Migrated config from version \(version) to \(Constants.currentSchemaVersion)")
        return config
    }
}
