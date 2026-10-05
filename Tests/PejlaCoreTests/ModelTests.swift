import XCTest
@testable import PejlaCore

final class ModelTests: XCTestCase {
    func testDisplayNamePrefersBonjour() {
        var host = ScannedHost(address: IPv4Address("10.0.0.9")!)
        XCTAssertEqual(host.displayName, "")
        host.hostname = "box.local"
        XCTAssertEqual(host.displayName, "box.local")
        host.bonjourName = "Living Room"
        XCTAssertEqual(host.displayName, "Living Room")
    }

    func testVendorDisplayFlagsRandomisedAddresses() {
        var host = ScannedHost(address: IPv4Address("10.0.0.9")!)
        host.macAddress = "da:1b:2c:3d:4e:5f"
        XCTAssertEqual(host.vendorDisplay, "Private address")
        host.vendor = "Apple"
        XCTAssertEqual(host.vendorDisplay, "Apple")
    }

    func testLatencyFormatting() {
        var host = ScannedHost(address: IPv4Address("10.0.0.9")!)
        XCTAssertEqual(host.latencyText, "")
        XCTAssertEqual(host.latencyMilliseconds, .greatestFiniteMagnitude)
        host.latency = 0.0004
        XCTAssertEqual(host.latencyText, "<1 ms")
        host.latency = 0.0123
        XCTAssertEqual(host.latencyText, "12 ms")
    }

    func testBonjourRecordLabels() {
        let record = BonjourRecord(name: "Office Printer", type: "_ipp._tcp.", hostName: "BRW1234.local.", addresses: [], port: 631, txt: [:])
        XCTAssertEqual(record.serviceLabel, "ipp")
        XCTAssertEqual(record.deviceName, "BRW1234.local")

        let cast = BonjourRecord(name: "Chromecast-abc", type: "_googlecast._tcp.", hostName: nil, addresses: [], port: 8009, txt: ["fn": "Kitchen display"])
        XCTAssertEqual(cast.deviceName, "Kitchen display")

        let airplay = BonjourRecord(name: "Living Room", type: "_airplay._tcp.", hostName: "Living-Room.local.", addresses: [], port: 7000, txt: [:])
        XCTAssertEqual(airplay.deviceName, "Living Room")
        XCTAssertLessThan(airplay.namePriority, record.namePriority)
    }

    func testKnownPortLabels() {
        XCTAssertEqual(KnownPorts.label(for: 22), "22 SSH")
        XCTAssertEqual(KnownPorts.label(for: 61000), "61000")
    }

    func testProbeLimiterAllowsAtMostNConcurrent() async {
        let limiter = ProbeLimiter(2)
        let counter = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await limiter.acquire()
                    await counter.enter()
                    try? await Task.sleep(nanoseconds: 2_000_000)
                    await counter.leave()
                    await limiter.release()
                }
            }
        }
        let peak = await counter.peak
        XCTAssertLessThanOrEqual(peak, 2)
        XCTAssertGreaterThan(peak, 0)
    }
}

private actor Counter {
    var current = 0
    var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() {
        current -= 1
    }
}
