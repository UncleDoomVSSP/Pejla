import XCTest
@testable import PejlaCore

final class ARPAndMACTests: XCTestCase {
    func testNormalisesShortOctets() {
        XCTAssertEqual(MACAddress.normalise("a4:5e:60:1:2:3"), "a4:5e:60:01:02:03")
        XCTAssertEqual(MACAddress.normalise("A4-5E-60-01-02-03"), "a4:5e:60:01:02:03")
        XCTAssertNil(MACAddress.normalise("(incomplete)"))
        XCTAssertNil(MACAddress.normalise("a4:5e:60:01:02"))
        XCTAssertNil(MACAddress.normalise("a4:5e:60:01:02:zz"))
    }

    func testLocallyAdministeredBit() {
        XCTAssertTrue(MACAddress.isLocallyAdministered("02:00:00:00:00:01"))
        XCTAssertTrue(MACAddress.isLocallyAdministered("da:1b:2c:3d:4e:5f"))
        XCTAssertFalse(MACAddress.isLocallyAdministered("a4:5e:60:01:02:03"))
    }

    func testOUIPrefix() {
        XCTAssertEqual(MACAddress.oui("b8:27:eb:aa:bb:cc"), "B827EB")
    }

    func testParsesArpOutput() {
        let output = """
        ? (192.168.1.1) at a4:5e:60:1:2:3 on en0 ifscope [ethernet]
        ? (192.168.1.5) at (incomplete) on en0 ifscope [ethernet]
        ? (192.168.1.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]
        ? (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]
        ? (192.168.1.42) at b8:27:eb:aa:bb:cc on en0 ifscope permanent [ethernet]
        garbage line
        """
        let entries = ARPTable.parse(output)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].address.description, "192.168.1.1")
        XCTAssertEqual(entries[0].macAddress, "a4:5e:60:01:02:03")
        XCTAssertEqual(entries[0].interface, "en0")
        XCTAssertEqual(entries[1].address.description, "192.168.1.42")
    }
}
