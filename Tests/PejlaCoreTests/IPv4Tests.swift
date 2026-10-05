import XCTest
@testable import PejlaCore

final class IPv4Tests: XCTestCase {
    func testParsesDottedQuad() {
        XCTAssertEqual(IPv4Address("192.168.1.10")?.value, 0xC0A8_010A)
        XCTAssertEqual(IPv4Address(" 10.0.0.1 ")?.description, "10.0.0.1")
        XCTAssertNil(IPv4Address("192.168.1"))
        XCTAssertNil(IPv4Address("192.168.1.256"))
        XCTAssertNil(IPv4Address("192.168.1.a"))
        XCTAssertNil(IPv4Address("192.168..1"))
        XCTAssertNil(IPv4Address("+1.2.3.4"))
    }

    func testFormatsRoundTrip() {
        let address = IPv4Address(0x0A00_00FF)
        XCTAssertEqual(address.description, "10.0.0.255")
        XCTAssertEqual(IPv4Address(address.description), address)
    }

    func testClassification() {
        XCTAssertTrue(IPv4Address("169.254.10.2")!.isLinkLocal)
        XCTAssertTrue(IPv4Address("127.0.0.1")!.isLoopback)
        XCTAssertTrue(IPv4Address("224.0.0.251")!.isMulticast)
        XCTAssertFalse(IPv4Address("192.168.0.1")!.isMulticast)
    }

    func testNetworkMaths() {
        let network = IPv4Network(cidr: "192.168.1.77/24")!
        XCTAssertEqual(network.address.description, "192.168.1.0")
        XCTAssertEqual(network.broadcast.description, "192.168.1.255")
        XCTAssertEqual(network.hostCount, 254)
        XCTAssertEqual(network.hostAddresses.first?.description, "192.168.1.1")
        XCTAssertEqual(network.hostAddresses.last?.description, "192.168.1.254")
        XCTAssertTrue(network.contains(IPv4Address("192.168.1.200")!))
        XCTAssertFalse(network.contains(IPv4Address("192.168.2.1")!))
        XCTAssertEqual(network.description, "192.168.1.0/24")
    }

    func testSmallPrefixes() {
        XCTAssertEqual(IPv4Network(cidr: "10.0.0.4/31")!.hostAddresses.map(\.description), ["10.0.0.4", "10.0.0.5"])
        XCTAssertEqual(IPv4Network(cidr: "10.0.0.4/32")!.hostAddresses.map(\.description), ["10.0.0.4"])
        XCTAssertEqual(IPv4Network(cidr: "10.0.0.0/30")!.hostCount, 2)
    }

    func testMaskConversions() {
        XCTAssertEqual(IPv4Network.mask(prefixLength: 24), 0xFFFF_FF00)
        XCTAssertEqual(IPv4Network.mask(prefixLength: 0), 0)
        XCTAssertEqual(IPv4Network.mask(prefixLength: 32), 0xFFFF_FFFF)
        XCTAssertEqual(IPv4Network.prefixLength(mask: 0xFFFF_FF00), 24)
        XCTAssertEqual(IPv4Network.prefixLength(mask: 0xFFFF_0000), 16)
    }

    func testRangeParsing() throws {
        XCTAssertEqual(try ScanRange.parse("192.168.1.0/30").map(\.description), ["192.168.1.1", "192.168.1.2"])
        XCTAssertEqual(try ScanRange.parse("192.168.1.10-12").map(\.description), ["192.168.1.10", "192.168.1.11", "192.168.1.12"])
        XCTAssertEqual(try ScanRange.parse("192.168.1.254 - 192.168.2.1").count, 4)
        XCTAssertEqual(try ScanRange.parse("10.1.2.3").map(\.description), ["10.1.2.3"])
    }

    func testRangeErrors() {
        XCTAssertThrowsError(try ScanRange.parse("")) { XCTAssertEqual($0 as? ScanRangeError, .empty) }
        XCTAssertThrowsError(try ScanRange.parse("192.168.1.0/33"))
        XCTAssertThrowsError(try ScanRange.parse("192.168.1.20-10"))
        XCTAssertThrowsError(try ScanRange.parse("banana"))
        XCTAssertThrowsError(try ScanRange.parse("10.0.0.0/8")) {
            guard case .tooLarge? = $0 as? ScanRangeError else { return XCTFail("expected tooLarge, got \($0)") }
        }
        XCTAssertNoThrow(try ScanRange.parse("10.0.0.0/16"))
    }
}
