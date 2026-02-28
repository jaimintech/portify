import Foundation

/// Parses project manifest files to extract project names.
struct ManifestParser {
    /// Manifest file names in priority order.
    static let manifestFiles = [
        "package.json",
        "Cargo.toml",
        "go.mod",
        "pyproject.toml",
        "setup.py",
        "Gemfile",
        "pom.xml",
        "build.gradle",
        "Package.swift",
        "mix.exs",
        "composer.json",
    ]

    /// Extract project name from a manifest file at the given path.
    func extractName(from manifestPath: String) -> String? {
        let url = URL(fileURLWithPath: manifestPath)
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let fileName = url.lastPathComponent

        switch fileName {
        case "package.json", "composer.json":
            return extractFromJSON(content, key: "name")
        case "Cargo.toml", "pyproject.toml":
            return extractFromTOML(content, key: "name")
        case "go.mod":
            return extractGoModule(content)
        case "mix.exs":
            return extractMixProject(content)
        case "pom.xml":
            return extractMavenArtifact(content)
        default:
            return nil
        }
    }

    private func extractFromJSON(_ content: String, key: String) -> String? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json[key] as? String,
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func extractFromTOML(_ content: String, key: String) -> String? {
        // Simple TOML parser — look for name = "value" in [package] or [project] section
        let lines = content.split(separator: "\n")
        var inRelevantSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                let section = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                inRelevantSection = (section == "package" || section == "project" || section == "tool.poetry")
                continue
            }

            if inRelevantSection && trimmed.hasPrefix("\(key)") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !value.isEmpty { return value }
                }
            }
        }
        return nil
    }

    private func extractGoModule(_ content: String) -> String? {
        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("module ") {
                let module = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                // Use last path component of module path
                return (module as NSString).lastPathComponent
            }
        }
        return nil
    }

    private func extractMixProject(_ content: String) -> String? {
        // Look for `app: :name` pattern
        let pattern = #"app:\s*:(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range])
    }

    private func extractMavenArtifact(_ content: String) -> String? {
        // Simple XML extraction for <artifactId>
        let pattern = #"<artifactId>([^<]+)</artifactId>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range])
    }
}
