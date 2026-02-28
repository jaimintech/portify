import PortifyCore
import Testing
import Foundation
@testable import Portify

@Suite("ProcessKiller Tests")
struct ProcessKillerTests {
    @Test("Normal kill flow — SIGTERM succeeds")
    func normalKillFlow() async throws {
        let signalSender = MockSignalSender()
        let procInfo = MockProcInfoProvider()
        let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

        let server = makeServer(pid: 1234, port: 3000, path: "/usr/local/bin/node")
        procInfo.executablePaths[1234] = "/usr/local/bin/node"
        procInfo.startTimes[1234] = server.processStartTime

        // Process is alive initially, then dead after SIGTERM
        signalSender.alivePids = [1234]
        signalSender.sendResult = true

        // Start kill, but it will check isAlive after sleep — simulate process dying
        let killTask = Task {
            try await killer.kill(server: server)
        }

        // After a short delay, simulate the process dying
        try await Task.sleep(for: .milliseconds(100))
        signalSender.alivePids = []

        try await killTask.value

        // Should have sent SIGTERM
        #expect(signalSender.sentSignals.contains { $0.signal == SIGTERM && $0.pid == 1234 })
    }

    @Test("PID reuse detection — path changed")
    func pidReusePathChanged() async {
        let signalSender = MockSignalSender()
        let procInfo = MockProcInfoProvider()
        let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

        let server = makeServer(pid: 1234, port: 3000, path: "/usr/local/bin/node")
        procInfo.executablePaths[1234] = "/usr/local/bin/python3"  // Different!
        signalSender.alivePids = [1234]

        do {
            try await killer.kill(server: server)
            Issue.record("Expected processChanged error")
        } catch let error as ProcessKiller.KillError {
            #expect(error == .processChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("PID reuse detection — start time changed")
    func pidReuseStartTimeChanged() async {
        let signalSender = MockSignalSender()
        let procInfo = MockProcInfoProvider()
        let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

        let originalTime = Date(timeIntervalSince1970: 1000)
        let server = makeServer(pid: 1234, port: 3000, path: "/usr/local/bin/node", startTime: originalTime)
        procInfo.executablePaths[1234] = "/usr/local/bin/node"
        procInfo.startTimes[1234] = Date(timeIntervalSince1970: 2000)  // Different!
        signalSender.alivePids = [1234]

        do {
            try await killer.kill(server: server)
            Issue.record("Expected processChanged error")
        } catch let error as ProcessKiller.KillError {
            #expect(error == .processChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Process already dead")
    func processAlreadyDead() async {
        let signalSender = MockSignalSender()
        let procInfo = MockProcInfoProvider()
        let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

        let server = makeServer(pid: 1234, port: 3000, path: "/usr/local/bin/node")
        procInfo.executablePaths[1234] = "/usr/local/bin/node"
        signalSender.alivePids = []  // Not alive

        do {
            try await killer.kill(server: server)
            Issue.record("Expected processAlreadyDead error")
        } catch let error as ProcessKiller.KillError {
            #expect(error == .processAlreadyDead)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("SIGTERM fails — signal returns false")
    func sigTermFails() async {
        let signalSender = MockSignalSender()
        let procInfo = MockProcInfoProvider()
        let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

        let server = makeServer(pid: 1234, port: 3000, path: "/usr/local/bin/node")
        procInfo.executablePaths[1234] = "/usr/local/bin/node"
        signalSender.alivePids = [1234]
        signalSender.sendResult = false

        do {
            try await killer.kill(server: server)
            Issue.record("Expected signalFailed error")
        } catch let error as ProcessKiller.KillError {
            #expect(error == .signalFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Force kill with revalidation")
    func forceKill() throws {
        let signalSender = MockSignalSender()
        let procInfo = MockProcInfoProvider()
        let killer = ProcessKiller(signalSender: signalSender, procInfo: procInfo)

        let server = makeServer(pid: 1234, port: 3000, path: "/usr/local/bin/node")
        procInfo.executablePaths[1234] = "/usr/local/bin/node"

        try killer.forceKill(server: server)
        #expect(signalSender.sentSignals.contains { $0.signal == SIGKILL && $0.pid == 1234 })
    }

    private func makeServer(
        pid: Int32,
        port: UInt16,
        path: String,
        startTime: Date? = Date(timeIntervalSince1970: 1000)
    ) -> DevServer {
        DevServer(
            pid: pid,
            port: port,
            processName: "node",
            processPath: path,
            processType: .node,
            projectName: "test-project",
            workingDirectory: "/tmp/test",
            processStartTime: startTime
        )
    }
}
