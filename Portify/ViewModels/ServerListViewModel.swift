import Foundation
import OSLog
import SwiftUI

/// A group of servers sharing the same project root.
struct ServerGroup: Identifiable {
    let id: String  // project name or working directory
    let projectName: String
    var servers: [DevServer]
    var isCollapsed: Bool = false
}

/// Main view model driving the server list UI.
@MainActor
final class ServerListViewModel: ObservableObject {
    @Published private(set) var servers: [DevServer] = []
    @Published private(set) var groups: [ServerGroup] = []
    @Published private(set) var isDegraded = false
    @Published private(set) var totalCount = 0
    @Published var pinnedPorts: Set<UInt16> = []
    @Published var customLabels: [UInt16: String] = [:]
    @Published var groupByProject = false
    @Published var killError: String?

    private let scanService: ScanService
    private let configStore: ConfigStore
    private let classifier = ProcessClassifier()
    private let projectIdentifier = ProjectIdentifier()
    private let procInfo: ProcInfoProviding
    private let processKiller: ProcessKiller?
    private let notificationService = NotificationService()

    private var refreshTask: Task<Void, Never>?

    init(
        scanService: ScanService,
        configStore: ConfigStore,
        procInfo: ProcInfoProviding? = nil,
        processKiller: ProcessKiller? = nil
    ) {
        self.scanService = scanService
        self.configStore = configStore
        self.procInfo = procInfo ?? DarwinProcInfo()
        self.processKiller = processKiller ?? ProcessKiller()
        startRefreshLoop()
    }

    func refresh() async {
        await scanService.forceScan()
        await updateServers()
    }

    func killServer(_ server: DevServer) async {
        guard let killer = processKiller else { return }
        killError = nil
        do {
            try await killer.kill(server: server)
            Logger.kill.info("Killed server on port \(server.port) (PID \(server.pid))")
            await refresh()
        } catch let error as ProcessKiller.KillError where error == .sigkillRequired {
            killError = error.localizedDescription
            Logger.kill.warning("SIGTERM insufficient for PID \(server.pid)")
        } catch {
            killError = error.localizedDescription
            Logger.kill.error("Failed to kill server: \(error.localizedDescription)")
        }
    }

    func forceKillServer(_ server: DevServer) {
        guard let killer = processKiller else { return }
        killError = nil
        do {
            try killer.forceKill(server: server)
            Logger.kill.info("Force killed server on port \(server.port) (PID \(server.pid))")
            Task { await refresh() }
        } catch {
            killError = error.localizedDescription
        }
    }

    // MARK: - Favorites / Pinning

    func togglePin(port: UInt16) {
        if pinnedPorts.contains(port) {
            pinnedPorts.remove(port)
        } else {
            pinnedPorts.insert(port)
        }
        reorderServers()
    }

    func isPinned(_ server: DevServer) -> Bool {
        pinnedPorts.contains(server.port)
    }

    // MARK: - Custom Labels

    func setCustomLabel(_ label: String?, for port: UInt16) {
        if let label, !label.isEmpty {
            customLabels[port] = label
        } else {
            customLabels.removeValue(forKey: port)
        }
    }

    func displayName(for server: DevServer) -> String {
        customLabels[server.port] ?? server.projectName
    }

    // MARK: - Grouping

    func toggleGroup(_ group: ServerGroup) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx].isCollapsed.toggle()
        }
    }

    // MARK: - Private

    private func startRefreshLoop() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateServers()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func updateServers() async {
        let rawPorts = await scanService.lastResults
        isDegraded = await scanService.isDegraded

        var resolved: [DevServer] = []
        for raw in rawPorts {
            let path = procInfo.executablePath(for: raw.pid) ?? ""
            let cwd = procInfo.workingDirectory(for: raw.pid) ?? ""
            let startTime = procInfo.startTime(for: raw.pid)
            let processType = classifier.classify(processName: raw.processName, path: path)
            let projectName = await projectIdentifier.identify(cwd: cwd, processName: raw.processName)

            resolved.append(DevServer(
                pid: raw.pid,
                port: raw.port,
                processName: raw.processName,
                processPath: path,
                processType: processType,
                projectName: projectName,
                workingDirectory: cwd,
                processStartTime: startTime
            ))
        }

        totalCount = resolved.count
        servers = Array(resolved.prefix(Constants.maxDisplayedServers))
        reorderServers()

        // Update groups
        if groupByProject {
            buildGroups()
        }

        // Notify
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "showNotifications")
        await notificationService.update(servers: servers, notificationsEnabled: notificationsEnabled)
    }

    private func reorderServers() {
        servers.sort { a, b in
            let aPinned = pinnedPorts.contains(a.port)
            let bPinned = pinnedPorts.contains(b.port)
            if aPinned != bPinned { return aPinned }
            return a.port < b.port
        }
    }

    private func buildGroups() {
        var groupMap: [String: [DevServer]] = [:]
        for server in servers {
            let key = server.workingDirectory.isEmpty ? server.projectName : server.workingDirectory
            groupMap[key, default: []].append(server)
        }

        groups = groupMap.map { key, servers in
            let name = servers.first?.projectName ?? key
            let existing = groups.first(where: { $0.id == key })
            return ServerGroup(
                id: key,
                projectName: name,
                servers: servers,
                isCollapsed: existing?.isCollapsed ?? false
            )
        }
        .sorted { $0.projectName < $1.projectName }
    }
}
