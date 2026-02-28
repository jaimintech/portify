import Foundation
import OSLog

/// Production implementation of ProcessLaunching using Foundation.Process.
struct FoundationProcessLauncher: ProcessLaunching {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> String {
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw ProcessLaunchError.executableNotFound(path: executableURL.path)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe() // Discard stderr

            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeout,
                execute: timeoutItem
            )

            do {
                try process.run()
                process.waitUntilExit()
                timeoutItem.cancel()

                if process.terminationReason == .uncaughtSignal {
                    continuation.resume(throwing: ProcessLaunchError.timeout)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                timeoutItem.cancel()
                continuation.resume(throwing: error)
            }
        }
    }
}
