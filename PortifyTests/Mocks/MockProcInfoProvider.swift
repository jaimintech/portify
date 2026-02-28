import Foundation
@testable import Portify

final class MockProcInfoProvider: ProcInfoProviding, @unchecked Sendable {
    var executablePaths: [Int32: String] = [:]
    var workingDirectories: [Int32: String] = [:]
    var startTimes: [Int32: Date] = [:]

    func executablePath(for pid: Int32) -> String? {
        executablePaths[pid]
    }

    func workingDirectory(for pid: Int32) -> String? {
        workingDirectories[pid]
    }

    func startTime(for pid: Int32) -> Date? {
        startTimes[pid]
    }
}
