import PortifyCore
import Testing
@testable import Portify

@Suite("LsofFParser Tests")
struct LsofFParserTests {
    let parser = LsofFParser()

    @Test("Parse normal output with 5 servers")
    func parseNormalOutput() {
        let output = """
        p1234
        cnode
        n*:3000
        p5678
        cpython3
        n127.0.0.1:8000
        p9012
        cruby
        n*:4567
        p3456
        cjava
        n*:8080
        p7890
        cgo
        n[::1]:9090
        """

        let results = parser.parse(output)

        #expect(results.count == 5)
        #expect(results[0].pid == 1234)
        #expect(results[0].port == 3000)
        #expect(results[0].processName == "node")
        #expect(results[1].pid == 5678)
        #expect(results[1].port == 8000)
        #expect(results[1].processName == "python3")
        #expect(results[4].pid == 7890)
        #expect(results[4].port == 9090)
    }

    @Test("Parse empty output")
    func parseEmptyOutput() {
        let results = parser.parse("")
        #expect(results.isEmpty)
    }

    @Test("Parse output with malformed lines — parser recovers")
    func parseMalformedLines() {
        let output = """
        p1234
        cnode
        n*:3000
        xunknown_field
        p5678
        cinvalid_pid_next
        n*:4000
        pnotanumber
        cbad
        n*:5000
        """

        let results = parser.parse(output)
        // First entry: valid
        // Second entry: valid (p5678)
        // Third entry: invalid pid, skipped
        #expect(results.count == 2)
        #expect(results[0].port == 3000)
        #expect(results[1].port == 4000)
    }

    @Test("IPv4 and IPv6 deduplication — same pid and port")
    func ipv4Ipv6Dedup() {
        let output = """
        p1234
        cnode
        n*:3000
        p1234
        cnode
        n[::]:3000
        """

        let results = parser.parse(output)
        #expect(results.count == 1)
        #expect(results[0].port == 3000)
    }

    @Test("IPv6-only output")
    func ipv6Only() {
        let output = """
        p1234
        cnode
        n[::1]:3000
        """

        let results = parser.parse(output)
        #expect(results.count == 1)
        #expect(results[0].address == "::1")
        #expect(results[0].port == 3000)
    }

    @Test("Large output with 100+ entries")
    func largeOutput() {
        var output = ""
        for i in 0..<150 {
            output += "p\(1000 + i)\ncnode\nn*:\(3000 + i)\n"
        }

        let results = parser.parse(output)
        #expect(results.count == 150)
    }

    @Test("Multiple ports per process")
    func multiplePortsPerProcess() {
        let output = """
        p1234
        cnode
        n*:3000
        n*:3001
        n*:3002
        """

        let results = parser.parse(output)
        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.pid == 1234 })
        #expect(results.allSatisfy { $0.processName == "node" })
    }

    @Test("Parse network name with localhost")
    func parseLocalhost() {
        let output = """
        p1234
        cnode
        nlocalhost:3000
        """

        let results = parser.parse(output)
        #expect(results.count == 1)
        #expect(results[0].address == "localhost")
        #expect(results[0].port == 3000)
    }
}
