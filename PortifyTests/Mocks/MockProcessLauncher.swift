import PortifyCore
import Foundation
@testable import Portify

final class MockProcessLauncher: ProcessLaunching, @unchecked Sendable {
    var runResult = ""
    var runError: Error?
    var runCalls: [(url: URL, arguments: [String])] = []

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> String {
        runCalls.append((url: executableURL, arguments: arguments))
        if let error = runError {
            throw error
        }
        return runResult
    }
}
