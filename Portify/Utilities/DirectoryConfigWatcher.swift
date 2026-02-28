import Foundation
import OSLog

/// Watches a directory for file changes using DispatchSource.
final class DirectoryConfigWatcher: ConfigWatching, @unchecked Sendable {
    private let directoryURL: URL
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL ?? ConfigStore.defaultConfigURL().deletingLastPathComponent()
    }

    func startWatching(handler: @escaping @Sendable () -> Void) throws {
        let path = directoryURL.path

        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            Logger.config.error("Failed to open directory for watching: \(path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        source.setEventHandler {
            Logger.config.debug("Config directory changed")
            handler()
        }

        source.setCancelHandler { [fileDescriptor] in
            close(fileDescriptor)
        }

        source.resume()
        self.source = source
        Logger.config.info("Watching config directory: \(path)")
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        Logger.config.info("Stopped watching config directory")
    }
}
