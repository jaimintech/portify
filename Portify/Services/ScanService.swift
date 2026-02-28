import PortifyCore
import Foundation
import OSLog

/// Actor-based service that periodically scans for listening TCP ports.
actor ScanService {
    private let scanner: PortScanning
    private let procInfo: ProcInfoProviding
    private var scanInterval: TimeInterval
    private var isScanning = false
    private var consecutiveFailures = 0
    private var scanTask: Task<Void, Never>?

    private(set) var lastResults: [RawListeningPort] = []
    private(set) var isDegraded = false

    init(
        scanner: PortScanning? = nil,
        procInfo: ProcInfoProviding? = nil,
        scanInterval: TimeInterval = Constants.defaultScanInterval
    ) {
        self.scanner = scanner ?? LsofPortScanner()
        self.procInfo = procInfo ?? DarwinProcInfo()
        self.scanInterval = scanInterval
    }

    func start() {
        guard scanTask == nil else { return }
        Logger.scanner.info("Scan service starting with interval \(self.scanInterval)s")

        scanTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.performScan()
                let interval = await self.currentInterval()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        Logger.scanner.info("Scan service stopped")
    }

    func forceScan() async {
        await performScan()
    }

    func updateInterval(_ interval: TimeInterval) {
        scanInterval = interval
    }

    private func performScan() async {
        guard !isScanning else {
            Logger.scanner.debug("Skipping scan — previous scan still in progress")
            return
        }

        isScanning = true
        defer { isScanning = false }

        do {
            let results = try await scanner.scan()
            lastResults = results
            consecutiveFailures = 0
            isDegraded = false
            Logger.scanner.info("Scan complete: \(results.count) listening ports found")
        } catch {
            consecutiveFailures += 1
            isDegraded = true
            Logger.scanner.error("Scan failed (\(self.consecutiveFailures) consecutive): \(error.localizedDescription)")
        }
    }

    private func currentInterval() -> TimeInterval {
        if consecutiveFailures >= Constants.backoffFailureThreshold {
            return min(scanInterval * 2, Constants.maxBackoffInterval)
        }
        return scanInterval
    }
}
