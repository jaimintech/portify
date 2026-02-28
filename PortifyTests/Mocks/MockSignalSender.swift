import Foundation
@testable import Portify

final class MockSignalSender: SignalSending, @unchecked Sendable {
    var sentSignals: [(signal: Int32, pid: Int32)] = []
    var sendResult = true
    var alivePids: Set<Int32> = []

    func send(signal: Int32, to pid: Int32) -> Bool {
        sentSignals.append((signal: signal, pid: pid))
        return sendResult
    }

    func isAlive(pid: Int32) -> Bool {
        alivePids.contains(pid)
    }
}
