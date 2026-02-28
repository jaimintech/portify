import PortifyCore
import Foundation
@testable import Portify

final class MockPortScanner: PortScanning, @unchecked Sendable {
    var scanResult: [RawListeningPort] = []
    var scanError: Error?
    var scanCallCount = 0

    func scan() async throws -> [RawListeningPort] {
        scanCallCount += 1
        if let error = scanError {
            throw error
        }
        return scanResult
    }
}
