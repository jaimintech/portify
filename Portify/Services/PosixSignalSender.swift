import Darwin
import Foundation

/// Production SignalSending implementation using POSIX kill(2).
struct PosixSignalSender: SignalSending {
    func send(signal: Int32, to pid: Int32) -> Bool {
        Darwin.kill(pid, signal) == 0
    }

    func isAlive(pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0
    }
}
