import Darwin
import Foundation

/// Production SignalSending implementation using POSIX kill(2).
public struct PosixSignalSender: SignalSending {
    public init() {}

    public func send(signal: Int32, to pid: Int32) -> Bool {
        Darwin.kill(pid, signal) == 0
    }

    public func isAlive(pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0
    }
}
