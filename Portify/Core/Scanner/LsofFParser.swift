import Foundation
import OSLog

/// State machine parser for lsof -F output format.
///
/// lsof -F pcn produces lines prefixed with field identifiers:
/// - `p` — PID (starts new process context)
/// - `c` — command name
/// - `n` — network name (address:port for TCP)
///
/// Unknown field prefixes are logged and skipped for forward compatibility.
struct LsofFParser {
    struct ParseError: Error {
        let message: String
    }

    func parse(_ output: String) -> [RawListeningPort] {
        var results: [RawListeningPort] = []
        var currentPID: Int32?
        var currentCommand: String?

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines {
            guard let firstChar = line.first else { continue }
            let value = String(line.dropFirst())

            switch firstChar {
            case "p":
                // New process context
                if let pid = Int32(value) {
                    currentPID = pid
                    currentCommand = nil
                } else {
                    Logger.scanner.warning("Invalid PID in lsof output: \(value)")
                    currentPID = nil
                    currentCommand = nil
                }

            case "c":
                currentCommand = value

            case "n":
                // Network name — parse address:port
                guard let pid = currentPID else { continue }
                let command = currentCommand ?? "unknown"

                if let (address, port) = parseNetworkName(value) {
                    results.append(RawListeningPort(
                        pid: pid,
                        port: port,
                        processName: command,
                        address: address
                    ))
                }

            default:
                // Unknown field — skip for forward compatibility
                Logger.scanner.debug("Unknown lsof field prefix: \(String(firstChar))")
            }
        }

        return deduplicate(results)
    }

    /// Parse "address:port" from lsof network name field.
    /// Handles: "*:3000", "127.0.0.1:3000", "[::1]:3000", "localhost:3000"
    private func parseNetworkName(_ name: String) -> (address: String, port: UInt16)? {
        // IPv6 bracket notation: [::1]:port
        if name.hasPrefix("[") {
            guard let closeBracket = name.firstIndex(of: "]") else { return nil }
            let address = String(name[name.index(after: name.startIndex)..<closeBracket])
            let afterBracket = name.index(after: closeBracket)
            guard afterBracket < name.endIndex,
                  name[afterBracket] == ":",
                  let port = UInt16(name[name.index(after: afterBracket)...]) else { return nil }
            return (address, port)
        }

        // Standard: address:port (split on last colon for IPv6 without brackets)
        guard let lastColon = name.lastIndex(of: ":") else { return nil }
        let address = String(name[..<lastColon])
        guard let port = UInt16(name[name.index(after: lastColon)...]) else { return nil }
        return (address, port)
    }

    /// Deduplicate by (pid, port) — IPv4+IPv6 may both be listening.
    private func deduplicate(_ ports: [RawListeningPort]) -> [RawListeningPort] {
        var seen = Set<String>()
        return ports.filter { port in
            let key = "\(port.pid):\(port.port)"
            return seen.insert(key).inserted
        }
    }
}
