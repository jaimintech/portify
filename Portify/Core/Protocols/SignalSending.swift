import Foundation

/// Abstraction over kill(2) for sending POSIX signals.
public protocol SignalSending: Sendable {
    /// Send a signal to a process. Returns true if successful.
    func send(signal: Int32, to pid: Int32) -> Bool

    /// Check if a process is alive (signal 0).
    func isAlive(pid: Int32) -> Bool
}
