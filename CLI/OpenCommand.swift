import ArgumentParser
import Foundation
import PortifyCore

extension PortifyCLI {
    struct Open: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Open a dev server in the default browser."
        )

        @Argument(help: "Port number of the server to open.")
        var port: UInt16

        func run() async throws {
            let scanner = LsofPortScanner()

            let ports: [RawListeningPort]
            do {
                ports = try await scanner.scan()
            } catch {
                throw CleanExit.message("Error: Failed to scan ports — \(error.localizedDescription)")
            }

            guard ports.contains(where: { $0.port == port }) else {
                // Still try to open even if not detected — user may know better
                print("Warning: No server detected on port \(port), opening anyway...")
                openURL(port: port)
                return
            }

            openURL(port: port)
            print("Opened http://localhost:\(port) in browser")
        }

        private func openURL(port: UInt16) {
            let url = URL(string: "http://localhost:\(port)")!
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [url.absoluteString]
            try? process.run()
        }
    }
}
