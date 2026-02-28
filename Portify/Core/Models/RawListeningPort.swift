import Foundation

/// Raw output from a port scan — a single listening TCP socket.
public struct RawListeningPort: Equatable, Sendable {
    public let pid: Int32
    public let port: UInt16
    public let processName: String
    public let address: String  // e.g. "*", "127.0.0.1", "::1"

    public init(pid: Int32, port: UInt16, processName: String, address: String) {
        self.pid = pid
        self.port = port
        self.processName = processName
        self.address = address
    }
}
