import PortifyCore
import Foundation
import OSLog

enum Constants {
    static let appName = "Portify"
    static let configDirectory = ".config/portify"
    static let configFileName = "config.json"
    static let currentSchemaVersion = 1

    static let defaultScanInterval: TimeInterval = 3.0
    static let minScanInterval: TimeInterval = 1.0
    static let maxScanInterval: TimeInterval = 30.0
    static let lsofTimeout: TimeInterval = 2.0
    static let sigTermGracePeriod: TimeInterval = 2.0

    static let maxBackoffInterval: TimeInterval = 30.0
    static let backoffFailureThreshold = 3

    static let maxDisplayedServers = 50

    static let lsofPath = "/usr/sbin/lsof"
}
