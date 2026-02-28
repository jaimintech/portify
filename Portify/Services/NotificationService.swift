import Foundation
import OSLog
import UserNotifications

/// Detects server start/stop events and sends macOS notifications.
actor NotificationService {
    private var previousPorts: Set<String> = []  // "pid:port" keys
    private var debounceTask: Task<Void, Never>?
    private var pendingEvents: [(type: EventType, server: DevServer)] = []
    private let debounceInterval: TimeInterval = 0.5

    enum EventType {
        case started
        case stopped
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            Logger.lifecycle.info("Notification permission \(granted ? "granted" : "denied")")
        } catch {
            Logger.lifecycle.error("Failed to request notification permission: \(error.localizedDescription)")
        }
    }

    func update(servers: [DevServer], notificationsEnabled: Bool) {
        guard notificationsEnabled else {
            previousPorts = Set(servers.map(\.id))
            return
        }

        let currentPorts = Set(servers.map(\.id))

        // Detect new servers
        let newPorts = currentPorts.subtracting(previousPorts)
        for server in servers where newPorts.contains(server.id) {
            pendingEvents.append((.started, server))
        }

        // Detect stopped servers — we'd need to track DevServer objects, but we can use the IDs
        let stoppedPorts = previousPorts.subtracting(currentPorts)
        if !stoppedPorts.isEmpty {
            // Send a summary notification for stopped servers
            for portId in stoppedPorts {
                let parts = portId.split(separator: ":")
                if parts.count == 2, let port = UInt16(parts[1]) {
                    sendStoppedNotification(port: port)
                }
            }
        }

        previousPorts = currentPorts

        // Debounce new server notifications
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(debounceInterval))
            guard !Task.isCancelled else { return }
            flushPendingEvents()
        }
    }

    private func flushPendingEvents() {
        for event in pendingEvents {
            switch event.type {
            case .started:
                sendStartedNotification(server: event.server)
            case .stopped:
                break // Already handled
            }
        }
        pendingEvents.removeAll()
    }

    private func sendStartedNotification(server: DevServer) {
        let content = UNMutableNotificationContent()
        content.title = "Server Started"
        content.body = "\(server.projectName) is running on port \(server.port)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "start-\(server.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.lifecycle.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    private func sendStoppedNotification(port: UInt16) {
        let content = UNMutableNotificationContent()
        content.title = "Server Stopped"
        content.body = "Server on port \(port) has stopped"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "stop-\(port)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.lifecycle.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
