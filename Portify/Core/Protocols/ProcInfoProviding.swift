import Foundation

/// Process information from the OS (proc_pidpath, proc_pidinfo).
protocol ProcInfoProviding: Sendable {
    /// Get the executable path for a PID.
    func executablePath(for pid: Int32) -> String?

    /// Get the current working directory for a PID.
    func workingDirectory(for pid: Int32) -> String?

    /// Get the process start time for a PID.
    func startTime(for pid: Int32) -> Date?
}
