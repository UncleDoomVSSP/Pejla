import Foundation

public struct ARPEntry: Hashable, Sendable {
    public let address: IPv4Address
    public let macAddress: String
    public let interface: String

    public init(address: IPv4Address, macAddress: String, interface: String) {
        self.address = address
        self.macAddress = macAddress
        self.interface = interface
    }
}

/// Reads the system ARP cache. Any device that answered an ARP request during
/// probing appears here with its hardware address, even if it accepted no TCP
/// connections, which makes this the most reliable liveness signal on a LAN.
public enum ARPTable {
    public static func read() async -> [ARPEntry] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: parse(runArp()))
            }
        }
    }

    static func runArp() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-an"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    public static func parse(_ output: String) -> [ARPEntry] {
        output.split(whereSeparator: \.isNewline).compactMap { parseLine(String($0)) }
    }

    /// Parses one line of `arp -an`, for example:
    /// `? (192.168.1.1) at a4:5e:60:1:2:3 on en0 ifscope [ethernet]`
    public static func parseLine(_ line: String) -> ARPEntry? {
        let tokens = line.split(separator: " ").map { String($0) }
        guard let atIndex = tokens.firstIndex(of: "at"), atIndex >= 1, atIndex + 1 < tokens.count else {
            return nil
        }
        let addressToken = tokens[atIndex - 1]
        guard addressToken.hasPrefix("("), addressToken.hasSuffix(")"),
              let address = IPv4Address(String(addressToken.dropFirst().dropLast())) else {
            return nil
        }
        guard let mac = MACAddress.normalise(tokens[atIndex + 1]) else { return nil }
        guard !MACAddress.isBroadcast(mac), !address.isMulticast else { return nil }
        var interface = ""
        if let onIndex = tokens.firstIndex(of: "on"), onIndex + 1 < tokens.count {
            interface = tokens[onIndex + 1]
        }
        return ARPEntry(address: address, macAddress: mac, interface: interface)
    }
}
