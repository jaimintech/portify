import Testing
@testable import Portify

@Suite("ProcessClassifier Tests")
struct ProcessClassifierTests {
    let classifier = ProcessClassifier()

    @Test("Known binary names map to correct ProcessType", arguments: [
        ("node", "", ProcessType.node),
        ("python3", "", ProcessType.python),
        ("go", "", ProcessType.go),
        ("ruby", "", ProcessType.ruby),
        ("java", "", ProcessType.java),
        ("cargo", "", ProcessType.rust),
        ("php", "", ProcessType.php),
        ("dotnet", "", ProcessType.dotnet),
        ("beam.smp", "", ProcessType.elixir),
        ("bun", "", ProcessType.node),
        ("uvicorn", "", ProcessType.python),
        ("puma", "", ProcessType.ruby),
        ("gunicorn", "", ProcessType.python),
    ])
    func knownBinaries(name: String, path: String, expected: ProcessType) {
        let result = classifier.classify(processName: name, path: path)
        #expect(result == expected)
    }

    @Test("Unknown binary returns .other")
    func unknownBinary() {
        let result = classifier.classify(processName: "mystery_server", path: "/usr/bin/mystery_server")
        #expect(result == .other)
    }

    @Test("Path-based classification when process name doesn't match")
    func pathBasedClassification() {
        let result = classifier.classify(processName: "my-app", path: "/usr/local/bin/node")
        #expect(result == .node)
    }

    @Test("Path contains runtime identifier")
    func pathContainsRuntime() {
        let result = classifier.classify(processName: "server", path: "/home/user/.nvm/versions/node/v18/bin/server")
        #expect(result == .node)
    }
}
