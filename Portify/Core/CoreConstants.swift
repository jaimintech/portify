import Foundation

/// Constants used by PortifyCore (shared between GUI and CLI).
public enum CoreConstants {
    public static let lsofPath = "/usr/sbin/lsof"
    public static let lsofTimeout: TimeInterval = 2.0
    public static let sigTermGracePeriod: TimeInterval = 2.0
    public static let currentSchemaVersion = 1
    public static let defaultScanInterval: TimeInterval = 3.0
}
