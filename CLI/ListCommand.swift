import ArgumentParser
import Foundation
import PortifyCore

extension PortifyCLI {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all detected dev servers."
        )

        @Option(name: .long, help: "Output format: json or table")
        var format: OutputFormat = .table

        enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
            case json
            case table
        }

        func run() async throws {
            let scanner = LsofPortScanner()
            let procInfo = DarwinProcInfo()
            let classifier = ProcessClassifier()

            let ports: [RawListeningPort]
            do {
                ports = try await scanner.scan()
            } catch {
                throw CleanExit.message("Error: Failed to scan ports — \(error.localizedDescription)")
            }

            if ports.isEmpty {
                print("No dev servers detected.")
                return
            }

            switch format {
            case .json:
                try outputJSON(ports: ports, procInfo: procInfo, classifier: classifier)
            case .table:
                outputTable(ports: ports, procInfo: procInfo, classifier: classifier)
            }
        }

        private func outputJSON(ports: [RawListeningPort], procInfo: DarwinProcInfo, classifier: ProcessClassifier) throws {
            struct ServerJSON: Encodable {
                let pid: Int32
                let port: UInt16
                let processName: String
                let processPath: String
                let processType: String
                let workingDirectory: String
            }

            let servers = ports.map { port in
                let path = procInfo.executablePath(for: port.pid) ?? ""
                let cwd = procInfo.workingDirectory(for: port.pid) ?? ""
                let type = classifier.classify(processName: port.processName, path: path)
                return ServerJSON(
                    pid: port.pid,
                    port: port.port,
                    processName: port.processName,
                    processPath: path,
                    processType: type.rawValue,
                    workingDirectory: cwd
                )
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(servers)
            print(String(data: data, encoding: .utf8) ?? "[]")
        }

        private func outputTable(ports: [RawListeningPort], procInfo: DarwinProcInfo, classifier: ProcessClassifier) {
            // Header
            let header = String(format: "%-6s %-8s %-12s %-20s %s", "PID", "PORT", "TYPE", "NAME", "CWD")
            print(header)
            print(String(repeating: "─", count: 80))

            for port in ports.sorted(by: { $0.port < $1.port }) {
                let path = procInfo.executablePath(for: port.pid) ?? ""
                let cwd = procInfo.workingDirectory(for: port.pid) ?? ""
                let type = classifier.classify(processName: port.processName, path: path)

                let dirName = (cwd as NSString).lastPathComponent
                let row = String(format: "%-6d %-8d %-12s %-20s %s",
                    port.pid,
                    port.port,
                    type.displayName,
                    port.processName,
                    dirName
                )
                print(row)
            }

            print("\n\(ports.count) server(s) detected")
        }
    }
}
