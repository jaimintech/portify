import AppKit
import Combine
import OSLog
import SwiftUI

/// Manages the NSStatusItem, renders badge count onto the icon.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private var cancellable: AnyCancellable?
    private var popover: NSPopover?

    var onTogglePopover: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
    }

    func bind(to viewModel: ServerListViewModel) {
        cancellable = viewModel.$servers
            .receive(on: RunLoop.main)
            .sink { [weak self] servers in
                self?.updateBadge(count: servers.count)
            }
    }

    func showPopover(with viewModel: ServerListViewModel) {
        guard let button = statusItem.button else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        self.popover = popover
    }

    // MARK: - Private

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = makeIcon(count: 0)
        button.action = #selector(AppDelegate.togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func updateBadge(count: Int) {
        statusItem.button?.image = makeIcon(count: count)

        let description: String
        if count == 0 {
            description = "Portify — no servers"
        } else if count == 1 {
            description = "Portify — 1 server"
        } else {
            description = "Portify — \(count) servers"
        }
        statusItem.button?.setAccessibilityTitle(description)
    }

    /// Render a menu bar icon with optional badge count.
    private func makeIcon(count: Int) -> NSImage {
        let baseSize = NSSize(width: 22, height: 22)
        let image = NSImage(size: baseSize, flipped: false) { rect in
            // Draw base icon
            if let symbol = NSImage(systemSymbolName: "network", accessibilityDescription: "Portify") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                let configured = symbol.withSymbolConfiguration(config) ?? symbol

                let symbolSize = configured.size
                let origin = NSPoint(
                    x: (rect.width - symbolSize.width) / 2,
                    y: (rect.height - symbolSize.height) / 2
                )

                // Dim when no servers
                if count == 0 {
                    configured.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 0.5)
                } else {
                    configured.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
                }
            }

            // Draw badge if count > 0
            if count > 0 {
                let badgeText = count > 9 ? "9+" : "\(count)"
                let font = NSFont.systemFont(ofSize: 8, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.white,
                ]
                let str = NSAttributedString(string: badgeText, attributes: attrs)
                let textSize = str.size()

                let badgeWidth = max(textSize.width + 4, 12)
                let badgeHeight: CGFloat = 10
                let badgeRect = NSRect(
                    x: rect.width - badgeWidth,
                    y: rect.height - badgeHeight,
                    width: badgeWidth,
                    height: badgeHeight
                )

                let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5)
                NSColor.systemRed.setFill()
                badgePath.fill()

                let textOrigin = NSPoint(
                    x: badgeRect.midX - textSize.width / 2,
                    y: badgeRect.midY - textSize.height / 2
                )
                str.draw(at: textOrigin)
            }

            return true
        }

        image.isTemplate = count == 0 // Template only when dimmed (no badge)
        return image
    }
}
