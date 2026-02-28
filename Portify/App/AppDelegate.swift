import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var popover: NSPopover?

    private let scanService = ScanService()
    private let configStore = ConfigStore()
    private lazy var viewModel = ServerListViewModel(scanService: scanService, configStore: configStore)

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.lifecycle.info("Portify launched")

        let controller = StatusItemController()
        controller.bind(to: viewModel)
        self.statusItemController = controller

        setupPopover()

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
                    Logger.config.info("Config reloaded — scan interval: \(config.scanInterval)s")
                }
            }
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )
        self.popover = popover
    }

    @objc func togglePopover() {
        statusItemController?.showPopover(with: viewModel)
    }
}
