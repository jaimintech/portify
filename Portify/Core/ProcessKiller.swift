import Foundation
import OSLog

/// Safely kills processes with PID revalidation to prevent killing wrong processes.
public final class ProcessKiller: Sendable {
    public enum KillError: Error, LocalizedError, Equatable {
        case processChanged
        case processAlreadyDead
        case signalFailed
        case sigkillRequired

        public var errorDescription: String? {
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

    public init(
        signalSender: SignalSending? = nil,
        procInfo: ProcInfoProviding? = nil
    ) {
        self.signalSender = signalSender ?? PosixSignalSender()
        self.procInfo = procInfo ?? DarwinProcInfo()
    }

    /// Kill a server process safely with PID revalidation.
    public func kill(server: DevServer) async throws {
        try revalidate(server: server)

        guard signalSender.isAlive(pid: server.pid) else {
            throw KillError.processAlreadyDead
        }

        Logger.kill.info("Sending SIGTERM to PID \(server.pid) (port \(server.port))")
        guard signalSender.send(signal: SIGTERM, to: server.pid) else {
            throw KillError.signalFailed
        }

        try await Task.sleep(for: .seconds(CoreConstants.sigTermGracePeriod))

        if signalSender.isAlive(pid: server.pid) {
            Logger.kill.warning("PID \(server.pid) still alive after SIGTERM")
            throw KillError.sigkillRequired
        }

        Logger.kill.info("PID \(server.pid) terminated successfully")
    }

    /// Force kill with SIGKILL after revalidation.
    public func forceKill(server: DevServer) throws {
        try revalidate(server: server)

        Logger.kill.info("Sending SIGKILL to PID \(server.pid)")
        guard signalSender.send(signal: SIGKILL, to: server.pid) else {
            throw KillError.signalFailed
        }
    }

    private func revalidate(server: DevServer) throws {
        if let currentPath = procInfo.executablePath(for: server.pid) {
            if currentPath != server.processPath && !server.processPath.isEmpty {
                Logger.kill.warning("PID \(server.pid) path changed: expected '\(server.processPath)', got '\(currentPath)'")
                throw KillError.processChanged
            }
        }

        if let storedTime = server.processStartTime,
           let currentTime = procInfo.startTime(for: server.pid) {
            if abs(storedTime.timeIntervalSince(currentTime)) > 1.0 {
                Logger.kill.warning("PID \(server.pid) start time changed")
                throw KillError.processChanged
            }
        }
    }
}
