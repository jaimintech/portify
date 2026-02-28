import Foundation

/// Raw output from a port scan — a single listening TCP socket.
struct RawListeningPort: Equatable, Sendable {
    let pid: Int32
    let port: UInt16
    let processName: String
    let address: String  // e.g. "*", "127.0.0.1", "::1"
}
