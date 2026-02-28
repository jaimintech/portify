import Foundation

/// A detected dev server with stable identity based on (pid, port).
public struct DevServer: Identifiable, Equatable, Sendable {
    /// Stable identity: combination of PID and port.
    public var id: String { "\(pid):\(port)" }

    public let pid: Int32
    public let port: UInt16
    public let processName: String
    public let processPath: String
    public let processType: ProcessType
    public let projectName: String
    public let workingDirectory: String
    public let processStartTime: Date?

    public init(pid: Int32, port: UInt16, processName: String, processPath: String, processType: ProcessType, projectName: String, workingDirectory: String, processStartTime: Date?) {
        self.pid = pid
        self.port = port
        self.processName = processName
        self.processPath = processPath
        self.processType = processType
        self.projectName = projectName
        self.workingDirectory = workingDirectory
        self.processStartTime = processStartTime
    }

    /// URL to open in the browser.
    public var url: URL? {
        URL(string: "http://localhost:\(port)")
    }

    /// Display-friendly port string.
    public var portString: String {
        ":\(port)"
    }
}
