import Foundation
import SystemConfiguration

/// A network interface with an IPv4 address assigned.
public struct NetworkInterface: Identifiable, Hashable, Sendable {
    public let name: String
    public let displayName: String
    public let address: IPv4Address
    public let netmask: IPv4Address
    public let macAddress: String?

    public init(name: String, displayName: String, address: IPv4Address, netmask: IPv4Address, macAddress: String?) {
        self.name = name
        self.displayName = displayName
        self.address = address
        self.netmask = netmask
        self.macAddress = macAddress
    }

    public var id: String { "\(name)/\(address)" }

    public var network: IPv4Network {
        IPv4Network(address: address, prefixLength: IPv4Network.prefixLength(mask: netmask.value))
    }

    public var label: String {
        "\(displayName) (\(name)) \(address)"
    }
}

public enum NetworkInterfaces {
    /// Virtual, tunnel and peer-to-peer interfaces that are never useful to scan.
    static let ignoredPrefixes = ["lo", "utun", "awdl", "llw", "gif", "stf", "ipsec", "pktap", "ap"]

    /// Lists interfaces that are up, running and have a routable IPv4 address.
    public static func list() -> [NetworkInterface] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let start = head else { return [] }
        defer { freeifaddrs(head) }

        let names = displayNames()
        var macs: [String: String] = [:]
        var found: [NetworkInterface] = []

        var cursor: UnsafeMutablePointer<ifaddrs>? = start
        while let entry = cursor {
            cursor = entry.pointee.ifa_next
            guard let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            if let mac = linkAddress(from: addr) {
                macs[name] = mac
            }
        }

        cursor = start
        while let entry = cursor {
            cursor = entry.pointee.ifa_next
            let flags = Int32(bitPattern: entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0 else { continue }
            guard let addr = entry.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET),
                  let maskPointer = entry.pointee.ifa_netmask else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            guard !ignoredPrefixes.contains(where: { name.hasPrefix($0) }) else { continue }
            let address = IPv4Address(ipv4(from: addr))
            let netmask = IPv4Address(ipv4(from: maskPointer))
            guard !address.isLinkLocal, !address.isLoopback else { continue }
            found.append(NetworkInterface(
                name: name,
                displayName: names[name] ?? name,
                address: address,
                netmask: netmask,
                macAddress: macs[name]
            ))
        }

        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func ipv4(from pointer: UnsafeMutablePointer<sockaddr>) -> UInt32 {
        pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
    }

    private static func linkAddress(from pointer: UnsafeMutablePointer<sockaddr>) -> String? {
        let raw = UnsafeRawPointer(pointer)
        let header = raw.loadUnaligned(as: sockaddr_dl.self)
        guard Int(header.sdl_alen) == 6 else { return nil }
        // sdl_data is variable length and starts after the eight fixed header
        // bytes: sdl_len, sdl_family, sdl_index (2), sdl_type, sdl_nlen, sdl_alen, sdl_slen.
        let dataOffset = 8
        let base = raw.advanced(by: dataOffset + Int(header.sdl_nlen))
        let bytes = (0..<6).map { base.load(fromByteOffset: $0, as: UInt8.self) }
        let mac = bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        return mac == "00:00:00:00:00:00" ? nil : mac
    }

    /// Maps BSD names (en0) to the names shown in System Settings (Wi-Fi).
    public static func displayNames() -> [String: String] {
        guard let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        var names: [String: String] = [:]
        for interface in all {
            guard let bsd = SCNetworkInterfaceGetBSDName(interface) as String? else { continue }
            if let localised = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? {
                names[bsd] = localised
            }
        }
        return names
    }

    /// The default IPv4 router and the interface it is reached through.
    public static func defaultGateway() -> (router: IPv4Address, interface: String)? {
        guard let store = SCDynamicStoreCreate(nil, "Pejla" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let routerText = value["Router"] as? String,
              let router = IPv4Address(routerText) else { return nil }
        let primary = value["PrimaryInterface"] as? String ?? ""
        return (router, primary)
    }
}
