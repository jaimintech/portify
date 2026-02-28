import Foundation

/// Known dev server process types.
enum ProcessType: String, Codable, Sendable, CaseIterable {
    case node
    case python
    case go
    case ruby
    case java
    case rust
    case php
    case dotnet
    case elixir
    case other

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .node: return "Node.js"
        case .python: return "Python"
        case .go: return "Go"
        case .ruby: return "Ruby"
        case .java: return "Java"
        case .rust: return "Rust"
        case .php: return "PHP"
        case .dotnet: return ".NET"
        case .elixir: return "Elixir"
        case .other: return "Other"
        }
    }

    /// SF Symbol name for this process type.
    var iconName: String {
        switch self {
        case .node: return "n.square.fill"
        case .python: return "p.square.fill"
        case .go: return "g.square.fill"
        case .ruby: return "r.square.fill"
        case .java: return "j.square.fill"
        case .rust: return "r.square.fill"
        case .php: return "p.square.fill"
        case .dotnet: return "d.square.fill"
        case .elixir: return "e.square.fill"
        case .other: return "questionmark.square.fill"
        }
    }
}
