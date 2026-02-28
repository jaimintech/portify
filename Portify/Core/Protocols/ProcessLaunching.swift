import Foundation

/// Abstraction over Foundation.Process for launching external commands.
public protocol ProcessLaunching: Sendable {
    /// Launch a process and return its stdout output.
    /// - Parameters:
    ///   - executableURL: Full path to the executable.
    ///   - arguments: Command-line arguments.
    ///   - timeout: Maximum execution time in seconds.
    /// - Returns: The stdout output as a string.
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> String
}

public enum ProcessLaunchError: Error, Sendable {
    case timeout
    case executionFailed(exitCode: Int32)
    case executableNotFound(path: String)
}
