import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.portify.app"

    public static let scanner = Logger(subsystem: subsystem, category: "scanner")
    public static let resolver = Logger(subsystem: subsystem, category: "resolver")
    public static let config = Logger(subsystem: subsystem, category: "config")
    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    public static let kill = Logger(subsystem: subsystem, category: "kill")
}
