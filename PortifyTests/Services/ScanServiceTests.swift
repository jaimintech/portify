import PortifyCore
import Testing
import Foundation
@testable import Portify

@Suite("ScanService Tests")
struct ScanServiceTests {
    @Test("Scan returns results from scanner")
    func scanReturnsResults() async throws {
        let scanner = MockPortScanner()
        scanner.scanResult = [
            RawListeningPort(pid: 1234, port: 3000, processName: "node", address: "*"),
            RawListeningPort(pid: 5678, port: 8000, processName: "python3", address: "127.0.0.1"),
        ]

        let service = ScanService(scanner: scanner, scanInterval: 60)
        await service.forceScan()

        let results = await service.lastResults
        #expect(results.count == 2)
        #expect(await service.isDegraded == false)
        #expect(scanner.scanCallCount == 1)
    }

    @Test("Degraded mode on scan failure — keeps previous results")
    func degradedMode() async throws {
        let scanner = MockPortScanner()
        scanner.scanResult = [
            RawListeningPort(pid: 1234, port: 3000, processName: "node", address: "*"),
        ]

        let service = ScanService(scanner: scanner, scanInterval: 60)

        // First scan succeeds
        await service.forceScan()
        #expect(await service.lastResults.count == 1)
        #expect(await service.isDegraded == false)

        // Second scan fails
        scanner.scanError = NSError(domain: "test", code: 1)
        await service.forceScan()

        // Still has previous results but is degraded
        #expect(await service.lastResults.count == 1)
        #expect(await service.isDegraded == true)
    }

    @Test("Empty scan — no servers")
    func emptyScan() async {
        let scanner = MockPortScanner()
        scanner.scanResult = []

        let service = ScanService(scanner: scanner, scanInterval: 60)
        await service.forceScan()

        #expect(await service.lastResults.isEmpty)
    }
}
