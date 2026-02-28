import Foundation

/// User-defined override for a specific port.
struct PortOverride: Codable, Equatable, Sendable {
    let port: UInt16
    var label: String?
    var hidden: Bool
    var pinned: Bool

    init(port: UInt16, label: String? = nil, hidden: Bool = false, pinned: Bool = false) {
        self.port = port
        self.label = label
        self.hidden = hidden
        self.pinned = pinned
    }
}
