import Foundation

/// File system event watcher for configuration changes.
public protocol ConfigWatching: Sendable {
    /// Start watching for changes. Calls handler on each detected change.
    func startWatching(handler: @escaping @Sendable () -> Void) throws

    /// Stop watching.
    func stopWatching()
}
