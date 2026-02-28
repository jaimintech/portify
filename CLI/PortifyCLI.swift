import ArgumentParser
import Foundation
import PortifyCore

@main
struct PortifyCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "portify",
        abstract: "Manage local dev servers from the command line.",
        version: "0.1.0",
        subcommands: [List.self, Kill.self, Open.self]
    )
}
