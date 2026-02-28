import PortifyCore
import Foundation
@testable import Portify

final class MockConfigWatcher: ConfigWatching, @unchecked Sendable {
    var watchHandler: (@Sendable () -> Void)?
    var isWatching = false

    func startWatching(handler: @escaping @Sendable () -> Void) throws {
        watchHandler = handler
        isWatching = true
    }

    func stopWatching() {
        isWatching = false
        watchHandler = nil
    }

    /// Simulate a file change event.
    func triggerChange() {
        watchHandler?()
    }
}
