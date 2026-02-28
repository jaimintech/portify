import Foundation

/// Abstraction over port scanning (lsof).
public protocol PortScanning: Sendable {
    /// Scan for all listening TCP ports. Returns deduplicated results.
    func scan() async throws -> [RawListeningPort]
}
