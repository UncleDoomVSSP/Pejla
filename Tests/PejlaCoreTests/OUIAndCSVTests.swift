import XCTest
@testable import PejlaCore

final class OUIAndCSVTests: XCTestCase {
    func testBuiltInLookup() {
        XCTAssertEqual(OUIDatabase.builtIn.vendor(forMAC: "b8:27:eb:12:34:56"), "Raspberry Pi Foundation")
        XCTAssertEqual(OUIDatabase.builtIn.vendor(forMAC: "a4:5e:60:00:00:00"), "Apple")
        XCTAssertNil(OUIDatabase.builtIn.vendor(forMAC: "02:00:00:00:00:00"))
        XCTAssertNil(OUIDatabase.builtIn.vendor(forMAC: "nonsense"))
    }

    func testParsesIEEECSV() {
        let csv = """
        Registry,Assignment,Organization Name,Organization Address
        MA-L,286FB9,"Nokia Shanghai Bell Co., Ltd.","No.388 Ning Qiao Road,Jin Qiao Pudong Shanghai Shanghai CN 201206"
        MA-L,000000,XEROX CORPORATION,M/S 105-50C WEBSTER NY US 14580
        MA-M,8C1F64,Something Medium,Nowhere
        """
        let table = OUIDatabase.parseIEEECSV(csv)
        XCTAssertEqual(table.count, 2)
        XCTAssertEqual(table["286FB9"], "Nokia Shanghai Bell Co., Ltd.")
        XCTAssertEqual(table["000000"], "XEROX CORPORATION")
        let database = OUIDatabase(table: table)
        XCTAssertEqual(database.vendor(forMAC: "28:6f:b9:00:11:22"), "Nokia Shanghai Bell Co., Ltd.")
    }

    func testCSVLineParsing() {
        XCTAssertEqual(CSV.parseLine("a,b,c"), ["a", "b", "c"])
        XCTAssertEqual(CSV.parseLine("\"a,b\",c"), ["a,b", "c"])
        XCTAssertEqual(CSV.parseLine("\"say \"\"hi\"\"\",x"), ["say \"hi\"", "x"])
        XCTAssertEqual(CSV.parseLine(""), [""])
    }

    func testCSVEscaping() {
        XCTAssertEqual(CSV.escape("plain"), "plain")
        XCTAssertEqual(CSV.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSV.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testExporterProducesHeaderAndRows() {
        var host = ScannedHost(address: IPv4Address("10.0.0.2")!)
        host.hostname = "printer.local"
        host.macAddress = "00:1b:a9:00:00:01"
        host.vendor = "Brother, Industries"
        host.openPorts = [80, 9100]
        host.latency = 0.0042
        host.evidence = [.tcp, .arp]
        let csv = CSVExporter.csv(for: [host])
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "IP address,Name,MAC address,Vendor,Open ports,Services,Latency (ms),Role,Evidence")
        XCTAssertEqual(lines[1], "10.0.0.2,printer.local,00:1b:a9:00:00:01,\"Brother, Industries\",80 HTTP; 9100 Printer raw,,4.2,,arp; tcp")
    }
}
