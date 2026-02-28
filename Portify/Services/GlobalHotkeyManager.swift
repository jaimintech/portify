import AppKit
import OSLog

/// Manages global hotkey (Option+P) for toggling the popover.
/// Requires Accessibility permission — uses NSEvent global monitor (no CGEvent taps).
@MainActor
final class GlobalHotkeyManager {
    private var monitor: Any?
    private var onToggle: (() -> Void)?

    var isEnabled: Bool { monitor != nil }

    func enable(onToggle: @escaping () -> Void) {
        guard monitor == nil else { return }

        guard AXIsProcessTrusted() else {
            Logger.lifecycle.warning("Global hotkey requested but Accessibility permission not granted")
            return
        }

        self.onToggle = onToggle
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Option+P
            if event.modifierFlags.contains(.option) && event.keyCode == 35 { // 35 = 'p'
                Task { @MainActor in
                    self?.onToggle?()
                }
            }
        }

        Logger.lifecycle.info("Global hotkey enabled (Option+P)")
    }

    func disable() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onToggle = nil
        Logger.lifecycle.info("Global hotkey disabled")
    }
}
