import Foundation
import OSLog

/// Identifies project names by walking directory trees for manifest files.
actor ProjectIdentifier {
    private var cache: [String: String] = [:]  // CWD → project name
    private let manifestParser = ManifestParser()

    /// Identify the project name for a given working directory.
    /// Fallback chain: manifest name → directory name → process name
    func identify(cwd: String, processName: String) -> String {
        if let cached = cache[cwd] {
            return cached
        }

        let name = resolveProjectName(cwd: cwd, processName: processName)
        cache[cwd] = name
        return name
    }

    /// Clear the cache (e.g., when a manual refresh is triggered).
    func clearCache() {
        cache.removeAll()
    }

    private func resolveProjectName(cwd: String, processName: String) -> String {
        guard !cwd.isEmpty else { return processName }

        // Walk up the directory tree looking for manifest files
        var dir = cwd
        let maxDepth = 5
        var depth = 0

        while depth < maxDepth {
            for manifestFile in ManifestParser.manifestFiles {
                let manifestPath = (dir as NSString).appendingPathComponent(manifestFile)
                if FileManager.default.fileExists(atPath: manifestPath) {
                    if let name = manifestParser.extractName(from: manifestPath) {
                        Logger.resolver.debug("Found project '\(name)' via \(manifestFile) in \(dir)")
                        return name
                    }
                }
            }

            // Move up one directory
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break } // Hit root
            dir = parent
            depth += 1
        }

        // Fallback: directory name
        let dirName = (cwd as NSString).lastPathComponent
        if !dirName.isEmpty && dirName != "/" {
            return dirName
        }

        // Last resort: process name
        return processName
    }
}
