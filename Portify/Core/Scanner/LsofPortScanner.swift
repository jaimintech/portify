import Foundation
import OSLog

/// Production PortScanning implementation using lsof -F.
struct LsofPortScanner: PortScanning {
    private let launcher: ProcessLaunching
    private let parser = LsofFParser()

    init(launcher: ProcessLaunching = FoundationProcessLauncher()) {
        self.launcher = launcher
    }

    func scan() async throws -> [RawListeningPort] {
        let startTime = CFAbsoluteTimeGetCurrent()

        let output = try await launcher.run(
            executableURL: URL(fileURLWithPath: Constants.lsofPath),
            arguments: ["-F", "pcn", "-iTCP", "-sTCP:LISTEN", "-P", "-n"],
            timeout: Constants.lsofTimeout
        )

        let results = parser.parse(output)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        Logger.scanner.info("lsof scan completed in \(String(format: "%.0f", elapsed * 1000))ms, found \(results.count) ports")

        return results
    }
}
