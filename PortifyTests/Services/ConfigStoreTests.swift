import Testing
import Foundation
@testable import Portify

@Suite("ConfigStore Tests")
struct ConfigStoreTests {
    @Test("Default config is created when no file exists")
    func defaultConfig() async {
        let url = tempConfigURL()
        let store = ConfigStore(configURL: url)
        let config = await store.currentConfig

        #expect(config.schemaVersion == Constants.currentSchemaVersion)
        #expect(config.scanInterval == Constants.defaultScanInterval)
        #expect(config.launchAtLogin == false)

        cleanup(url)
    }

    @Test("Config roundtrip — save and reload")
    func configRoundtrip() async throws {
        let url = tempConfigURL()
        let store = ConfigStore(configURL: url)

        try await store.update { config in
            config.scanInterval = 10.0
            config.launchAtLogin = true
            config.sortOrder = .name
        }

        // Create new store from same URL — should load saved config
        let store2 = ConfigStore(configURL: url)
        let config = await store2.currentConfig

        #expect(config.scanInterval == 10.0)
        #expect(config.launchAtLogin == true)
        #expect(config.sortOrder == .name)

        cleanup(url)
    }

    @Test("Corrupt JSON falls back to defaults")
    func corruptJson() async throws {
        let url = tempConfigURL()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "{ not valid json".write(to: url, atomically: true, encoding: .utf8)

        let store = ConfigStore(configURL: url)
        let config = await store.currentConfig
        #expect(config == .default)

        cleanup(url)
    }

    @Test("Future schema version falls back to defaults")
    func futureSchemaVersion() async throws {
        let url = tempConfigURL()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var futureConfig = AppConfig.default
        futureConfig.schemaVersion = 999
        let data = try JSONEncoder().encode(futureConfig)
        try data.write(to: url)

        let store = ConfigStore(configURL: url)
        let config = await store.currentConfig
        #expect(config == .default)

        cleanup(url)
    }

    @Test("File permissions are set to 0600")
    func filePermissions() async throws {
        let url = tempConfigURL()
        let store = ConfigStore(configURL: url)

        try await store.update { $0.scanInterval = 5.0 }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attrs[.posixPermissions] as? Int
        #expect(permissions == 0o600)

        cleanup(url)
    }

    @Test("Config watcher triggers on change")
    func configWatcher() async throws {
        let url = tempConfigURL()
        let store = ConfigStore(configURL: url)
        let watcher = MockConfigWatcher()

        var receivedConfig: AppConfig?
        await store.startWatching(watcher: watcher) { config in
            receivedConfig = config
        }

        #expect(watcher.isWatching)

        // Write a new config file directly
        try await store.update { $0.scanInterval = 15.0 }

        // Simulate watcher firing
        watcher.triggerChange()

        // Give async handler time to process
        try await Task.sleep(for: .milliseconds(100))

        #expect(receivedConfig?.scanInterval == 15.0)

        await store.stopWatching()
        #expect(!watcher.isWatching)

        cleanup(url)
    }

    private func tempConfigURL() -> URL {
        let dir = NSTemporaryDirectory() + "portify-config-test-\(UUID().uuidString)"
        return URL(fileURLWithPath: dir).appendingPathComponent("config.json")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
