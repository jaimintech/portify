import Foundation
import OSLog

/// Safely kills processes with PID revalidation to prevent killing wrong processes.
final class ProcessKiller: Sendable {
    enum KillError: Error, LocalizedError {
        case processChanged
        case processAlreadyDead
        case signalFailed
        case sigkillRequired

        var errorDescription: String? {
            switch self {
            case .processChanged:
                return "Process has changed since listed. Refreshing..."
            case .processAlreadyDead:
                return "Process is no longer running."
            case .signalFailed:
                return "Failed to send signal to process."
            case .sigkillRequired:
                return "Process did not respond to SIGTERM. SIGKILL may be required."
            }
        }
    }

    private let signalSender: SignalSending
    private let procInfo: ProcInfoProviding

    init(
        signalSender: SignalSending? = nil,
        procInfo: ProcInfoProviding? = nil
    ) {
        self.signalSender = signalSender ?? PosixSignalSender()
        self.procInfo = procInfo ?? DarwinProcInfo()
    }

    /// Kill a server process safely with PID revalidation.
    func kill(server: DevServer) async throws {
        // Step 1: Revalidate before SIGTERM
        try revalidate(server: server)

        // Step 2: Check if already dead
        guard signalSender.isAlive(pid: server.pid) else {
            throw KillError.processAlreadyDead
        }

        // Step 3: Send SIGTERM
        Logger.kill.info("Sending SIGTERM to PID \(server.pid) (port \(server.port))")
        guard signalSender.send(signal: SIGTERM, to: server.pid) else {
            throw KillError.signalFailed
        }

        // Step 4: Wait grace period
        try await Task.sleep(for: .seconds(Constants.sigTermGracePeriod))

        // Step 5: Check if process died
        if signalSender.isAlive(pid: server.pid) {
            Logger.kill.warning("PID \(server.pid) still alive after SIGTERM")
            throw KillError.sigkillRequired
        }

        Logger.kill.info("PID \(server.pid) terminated successfully")
    }

    /// Force kill with SIGKILL after revalidation.
    func forceKill(server: DevServer) throws {
        try revalidate(server: server)

        Logger.kill.info("Sending SIGKILL to PID \(server.pid)")
        guard signalSender.send(signal: SIGKILL, to: server.pid) else {
            throw KillError.signalFailed
        }
    }

    /// Revalidate that the PID still corresponds to the same process.
    private func revalidate(server: DevServer) throws {
        // Check path still matches
        if let currentPath = procInfo.executablePath(for: server.pid) {
            if currentPath != server.processPath && !server.processPath.isEmpty {
                Logger.kill.warning("PID \(server.pid) path changed: expected '\(server.processPath)', got '\(currentPath)'")
                throw KillError.processChanged
            }
        }

        // Check start time still matches
        if let storedTime = server.processStartTime,
           let currentTime = procInfo.startTime(for: server.pid) {
            if abs(storedTime.timeIntervalSince(currentTime)) > 1.0 {
                Logger.kill.warning("PID \(server.pid) start time changed")
                throw KillError.processChanged
            }
        }
    }
}
