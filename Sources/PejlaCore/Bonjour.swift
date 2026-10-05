import Foundation

public struct BonjourRecord: Sendable {
    public let name: String
    public let type: String
    public let hostName: String?
    public let addresses: [IPv4Address]
    public let port: Int
    public let txt: [String: String]

    /// Human readable service label, e.g. "airplay" from "_airplay._tcp.".
    public var serviceLabel: String {
        var label = type
        if label.hasSuffix(".") { label.removeLast() }
        for suffix in ["._tcp", "._udp"] where label.hasSuffix(suffix) {
            label.removeLast(suffix.count)
        }
        if label.hasPrefix("_") { label.removeFirst() }
        return label
    }

    /// The friendliest device name this record can offer.
    public var deviceName: String? {
        if type.hasPrefix("_googlecast"), let friendly = txt["fn"], !friendly.isEmpty {
            return friendly
        }
        if BonjourDiscovery.deviceNameTypes.contains(type), !name.isEmpty {
            return name
        }
        if var host = hostName, !host.isEmpty {
            if host.hasSuffix(".") { host.removeLast() }
            return host
        }
        return name.isEmpty ? nil : name
    }

    /// Lower is better.
    public var namePriority: Int {
        BonjourDiscovery.deviceNameTypes.firstIndex(of: type) ?? BonjourDiscovery.deviceNameTypes.count
    }
}

/// Browses common Bonjour service types for a fixed duration and resolves
/// every service found to its IPv4 addresses.
public final class BonjourDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    /// Service types whose instance name is normally the device name.
    public static let deviceNameTypes = [
        "_companion-link._tcp.", "_rdlink._tcp.", "_airplay._tcp.", "_googlecast._tcp.",
        "_smb._tcp.", "_afpovertcp._tcp.", "_sonos._tcp.", "_hap._tcp.", "_raop._tcp.",
    ]

    public static let serviceTypes = [
        "_companion-link._tcp.", "_rdlink._tcp.", "_airplay._tcp.", "_raop._tcp.",
        "_googlecast._tcp.", "_smb._tcp.", "_afpovertcp._tcp.", "_ssh._tcp.",
        "_sftp-ssh._tcp.", "_http._tcp.", "_https._tcp.", "_printer._tcp.", "_ipp._tcp.",
        "_ipps._tcp.", "_hap._tcp.", "_homekit._tcp.", "_spotify-connect._tcp.",
        "_sonos._tcp.", "_workstation._tcp.", "_rfb._tcp.", "_adisk._tcp.",
        "_daap._tcp.", "_mqtt._tcp.", "_hue._tcp.", "_matter._tcp.", "_matterc._udp.",
        "_androidtvremote2._tcp.", "_sleep-proxy._udp.", "_nvstream._tcp.",
        "_plexmediasvr._tcp.", "_home-assistant._tcp.", "_esphomelib._tcp.",
        "_shelly._tcp.", "_scanner._tcp.", "_pdl-datastream._tcp.",
    ]

    private var browsers: [NetServiceBrowser] = []
    private var pending: [NetService] = []
    private var records: [BonjourRecord] = []

    public override init() {
        super.init()
    }

    @MainActor
    public func discover(duration: TimeInterval) async -> [BonjourRecord] {
        for type in Set(Self.serviceTypes) {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.schedule(in: .main, forMode: .common)
            browser.searchForServices(ofType: type, inDomain: "local.")
            browsers.append(browser)
        }
        let nanoseconds = UInt64(max(duration, 0.5) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        for browser in browsers {
            browser.stop()
        }
        browsers.removeAll()
        for service in pending {
            service.stop()
        }
        pending.removeAll()
        return records
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.schedule(in: .main, forMode: .common)
        pending.append(service)
        service.resolve(withTimeout: 4)
    }

    public func netServiceDidResolveAddress(_ sender: NetService) {
        var addresses: [IPv4Address] = []
        for data in sender.addresses ?? [] {
            guard data.count >= MemoryLayout<sockaddr_in>.size else { continue }
            let family = data.withUnsafeBytes { $0.loadUnaligned(as: sockaddr.self).sa_family }
            guard family == UInt8(AF_INET) else { continue }
            let socketAddress = data.withUnsafeBytes { $0.loadUnaligned(as: sockaddr_in.self) }
            addresses.append(IPv4Address(UInt32(bigEndian: socketAddress.sin_addr.s_addr)))
        }
        var txt: [String: String] = [:]
        if let txtData = sender.txtRecordData() {
            for (key, value) in NetService.dictionary(fromTXTRecord: txtData) {
                txt[key] = String(decoding: value, as: UTF8.self)
            }
        }
        records.append(BonjourRecord(
            name: sender.name,
            type: sender.type,
            hostName: sender.hostName,
            addresses: addresses,
            port: sender.port,
            txt: txt
        ))
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        // Nothing to do; the service simply stays unnamed.
    }
}
