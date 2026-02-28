import Foundation

/// User-defined override for a specific port.
public struct PortOverride: Codable, Equatable, Sendable {
    public let port: UInt16
    public var label: String?
    public var hidden: Bool
    public var pinned: Bool

    public init(port: UInt16, label: String? = nil, hidden: Bool = false, pinned: Bool = false) {
        self.port = port
        self.label = label
        self.hidden = hidden
        self.pinned = pinned
    }
}
