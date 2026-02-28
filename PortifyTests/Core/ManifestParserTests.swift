import PortifyCore
import Testing
import Foundation
@testable import Portify

@Suite("ManifestParser Tests")
struct ManifestParserTests {
    let parser = ManifestParser()

    @Test("Extract name from package.json")
    func packageJson() throws {
        let dir = try createTempDir()
        let path = (dir as NSString).appendingPathComponent("package.json")
        try #"{"name": "my-react-app", "version": "1.0.0"}"#.write(toFile: path, atomically: true, encoding: .utf8)

        let name = parser.extractName(from: path)
        #expect(name == "my-react-app")

        try FileManager.default.removeItem(atPath: dir)
    }

    @Test("Extract name from Cargo.toml")
    func cargoToml() throws {
        let dir = try createTempDir()
        let path = (dir as NSString).appendingPathComponent("Cargo.toml")
        let content = """
        [package]
        name = "my-rust-app"
        version = "0.1.0"
        edition = "2021"
        """
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        let name = parser.extractName(from: path)
        #expect(name == "my-rust-app")

        try FileManager.default.removeItem(atPath: dir)
    }

    @Test("Extract name from go.mod")
    func goMod() throws {
        let dir = try createTempDir()
        let path = (dir as NSString).appendingPathComponent("go.mod")
        let content = """
        module github.com/user/my-go-service

        go 1.21
        """
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        let name = parser.extractName(from: path)
        #expect(name == "my-go-service")

        try FileManager.default.removeItem(atPath: dir)
    }

    @Test("Extract name from pyproject.toml")
    func pyprojectToml() throws {
        let dir = try createTempDir()
        let path = (dir as NSString).appendingPathComponent("pyproject.toml")
        let content = """
        [project]
        name = "my-python-api"
        version = "0.1.0"
        """
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        let name = parser.extractName(from: path)
        #expect(name == "my-python-api")

        try FileManager.default.removeItem(atPath: dir)
    }

    @Test("Extract name from composer.json")
    func composerJson() throws {
        let dir = try createTempDir()
        let path = (dir as NSString).appendingPathComponent("composer.json")
        try #"{"name": "vendor/my-php-app"}"#.write(toFile: path, atomically: true, encoding: .utf8)

        let name = parser.extractName(from: path)
        #expect(name == "vendor/my-php-app")

        try FileManager.default.removeItem(atPath: dir)
    }

    @Test("Returns nil for missing file")
    func missingFile() {
        let name = parser.extractName(from: "/nonexistent/package.json")
        #expect(name == nil)
    }

    @Test("Returns nil for empty JSON")
    func emptyJson() throws {
        let dir = try createTempDir()
        let path = (dir as NSString).appendingPathComponent("package.json")
        try "{}".write(toFile: path, atomically: true, encoding: .utf8)

        let name = parser.extractName(from: path)
        #expect(name == nil)

        try FileManager.default.removeItem(atPath: dir)
    }

    private func createTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "portify-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
