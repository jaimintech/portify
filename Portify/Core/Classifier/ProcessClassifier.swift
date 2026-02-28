import Foundation

/// Maps binary names to ProcessType for known dev server runtimes.
public struct ProcessClassifier {
    public init() {}
    /// Binary name → ProcessType mapping table.
    private static let binaryMap: [String: ProcessType] = [
        // Node.js
        "node": .node,
        "nodejs": .node,
        "npx": .node,
        "tsx": .node,
        "ts-node": .node,
        "bun": .node,
        "deno": .node,

        // Python
        "python": .python,
        "python3": .python,
        "python3.11": .python,
        "python3.12": .python,
        "python3.13": .python,
        "uvicorn": .python,
        "gunicorn": .python,
        "flask": .python,
        "django": .python,

        // Go
        "go": .go,

        // Ruby
        "ruby": .ruby,
        "rails": .ruby,
        "puma": .ruby,
        "unicorn": .ruby,

        // Java
        "java": .java,
        "gradle": .java,
        "mvn": .java,

        // Rust
        "cargo": .rust,

        // PHP
        "php": .php,
        "php-fpm": .php,

        // .NET
        "dotnet": .dotnet,

        // Elixir
        "beam.smp": .elixir,
        "elixir": .elixir,
        "mix": .elixir,
    ]

    /// Classify a process by its binary name and path.
    public func classify(processName: String, path: String) -> ProcessType {
        // Try direct lookup first
        let name = processName.lowercased()
        if let type = Self.binaryMap[name] {
            return type
        }

        // Try matching against the binary name from the path
        let binaryName = (path as NSString).lastPathComponent.lowercased()
        if let type = Self.binaryMap[binaryName] {
            return type
        }

        // Check if the path contains known runtime identifiers
        let pathLower = path.lowercased()
        if pathLower.contains("/node") { return .node }
        if pathLower.contains("/python") { return .python }
        if pathLower.contains("/ruby") { return .ruby }
        if pathLower.contains("/java") { return .java }

        return .other
    }
}
