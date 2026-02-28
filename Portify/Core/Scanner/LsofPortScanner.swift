import Foundation
import OSLog

/// Production PortScanning implementation using lsof -F.
public struct LsofPortScanner: PortScanning {
    private let launcher: ProcessLaunching
    private let parser = LsofFParser()

    public init(launcher: ProcessLaunching = FoundationProcessLauncher()) {
        self.launcher = launcher
    }

    public func scan() async throws -> [RawListeningPort] {
        let startTime = CFAbsoluteTimeGetCurrent()

        let output = try await launcher.run(
            executableURL: URL(fileURLWithPath: CoreConstants.lsofPath),
            arguments: ["-F", "pcn", "-iTCP", "-sTCP:LISTEN", "-P", "-n"],
            timeout: CoreConstants.lsofTimeout
        )

        let results = parser.parse(output)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        Logger.scanner.info("lsof scan completed in \(String(format: "%.0f", elapsed * 1000))ms, found \(results.count) ports")

        return results
    }
}
