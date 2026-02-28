import ArgumentParser
import Foundation
import PortifyCore

extension PortifyCLI {
    struct Kill: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Kill a dev server by port number."
        )

        @Argument(help: "Port number of the server to kill.")
        var port: UInt16

        @Flag(name: .shortAndLong, help: "Force kill with SIGKILL instead of SIGTERM.")
        var force = false

        func run() async throws {
            let scanner = LsofPortScanner()
            let procInfo = DarwinProcInfo()
            let signalSender = PosixSignalSender()

            let ports: [RawListeningPort]
            do {
                ports = try await scanner.scan()
            } catch {
                throw CleanExit.message("Error: Failed to scan ports — \(error.localizedDescription)")
            }

            guard let target = ports.first(where: { $0.port == port }) else {
                throw CleanExit.message("No server found on port \(port).")
            }

            let path = procInfo.executablePath(for: target.pid) ?? ""
            let startTime = procInfo.startTime(for: target.pid)

            let server = DevServer(
                pid: target.pid,
                port: target.port,
                processName: target.processName,
                processPath: path,
                processType: .other,
                projectName: target.processName,
                workingDirectory: "",
                processStartTime: startTime
            )

            let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

            if force {
                do {
                    try killer.forceKill(server: server)
                    print("Force killed \(target.processName) on port \(port) (PID \(target.pid))")
                } catch {
                    throw CleanExit.message("Error: \(error.localizedDescription)")
                }
            } else {
                do {
                    try await killer.kill(server: server)
                    print("Killed \(target.processName) on port \(port) (PID \(target.pid))")
                } catch ProcessKiller.KillError.sigkillRequired {
                    print("Process did not respond to SIGTERM. Use --force to send SIGKILL.")
                } catch {
                    throw CleanExit.message("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
