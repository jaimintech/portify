import Foundation
import OSLog
import SwiftUI

/// Main view model driving the server list UI.
@MainActor
final class ServerListViewModel: ObservableObject {
    @Published private(set) var servers: [DevServer] = []
    @Published private(set) var isDegraded = false
    @Published private(set) var totalCount = 0

    private let scanService: ScanService
    private let configStore: ConfigStore
    private let classifier = ProcessClassifier()
    private let projectIdentifier = ProjectIdentifier()
    private let procInfo: ProcInfoProviding
    private let processKiller: ProcessKiller?

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
        do {
            try await killer.kill(server: server)
            Logger.kill.info("Killed server on port \(server.port) (PID \(server.pid))")
            await refresh()
        } catch {
            Logger.kill.error("Failed to kill server: \(error.localizedDescription)")
        }
    }

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
    }
}
