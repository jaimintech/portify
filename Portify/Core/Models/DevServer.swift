import Foundation

/// A detected dev server with stable identity based on (pid, port).
struct DevServer: Identifiable, Equatable, Sendable {
    /// Stable identity: combination of PID and port.
    var id: String { "\(pid):\(port)" }

    let pid: Int32
    let port: UInt16
    let processName: String
    let processPath: String
    let processType: ProcessType
    let projectName: String
    let workingDirectory: String
    let processStartTime: Date?

    /// URL to open in the browser.
    var url: URL? {
        URL(string: "http://localhost:\(port)")
    }

    /// Display-friendly port string.
    var portString: String {
        ":\(port)"
    }
}
