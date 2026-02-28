import PortifyCore
import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let hotkeyManager = GlobalHotkeyManager()

    private let scanService = ScanService()
    private let configStore = ConfigStore()
    private lazy var viewModel = ServerListViewModel(scanService: scanService, configStore: configStore)

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.lifecycle.info("Portify launched")

        let controller = StatusItemController()
        controller.bind(to: viewModel)
        self.statusItemController = controller

        Task {
            await scanService.start()
        }

        // Start config file watching
        let watcher = DirectoryConfigWatcher()
        Task {
            await configStore.startWatching(watcher: watcher) { [weak self] config in
                Task { @MainActor in
                    guard let self else { return }
                    await self.scanService.updateInterval(config.scanInterval)

                    // Update hotkey state
                    if config.globalHotkeyEnabled {
                        self.hotkeyManager.enable { [weak self] in
                            self?.togglePopover()
                        }
                    } else {
                        self.hotkeyManager.disable()
                    }

                    Logger.config.info("Config reloaded — scan interval: \(config.scanInterval)s")
                }
            }
        }

        // Enable global hotkey if configured
        if UserDefaults.standard.bool(forKey: "globalHotkeyEnabled") {
            hotkeyManager.enable { [weak self] in
                self?.togglePopover()
            }
        }
    }

    @objc func togglePopover() {
        statusItemController?.showPopover(with: viewModel)
    }
}
