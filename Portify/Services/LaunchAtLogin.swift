import Foundation
import OSLog
import ServiceManagement

/// Manages launch-at-login via SMAppService.
struct LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            Logger.lifecycle.info("Launch at login enabled")
        } else {
            try SMAppService.mainApp.unregister()
            Logger.lifecycle.info("Launch at login disabled")
        }
    }
}
