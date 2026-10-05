import Foundation

public enum ScanPhase: Equatable, Sendable {
    case idle
    case discovering
    case probingServices
    case resolvingNames
    case finished
    case cancelled

    public var title: String {
        switch self {
        case .idle: return "Ready"
        case .discovering: return "Finding devices"
        case .probingServices: return "Checking services"
        case .resolvingNames: return "Resolving names"
        case .finished: return "Finished"
        case .cancelled: return "Stopped"
        }
    }

    public var isActive: Bool {
        switch self {
        case .discovering, .probingServices, .resolvingNames: return true
        case .idle, .finished, .cancelled: return false
        }
    }
}

/// How Pejla learned that a device exists.
public enum HostEvidence: String, Hashable, Sendable, CaseIterable, Comparable {
    case tcp
    case arp
    case bonjour
    case local

    public var title: String {
        switch self {
        case .tcp: return "Answered a TCP probe"
        case .arp: return "Answered ARP (hardware address seen)"
        case .bonjour: return "Advertises Bonjour services"
        case .local: return "This Mac"
        }
    }

    public static func < (lhs: HostEvidence, rhs: HostEvidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ScannedHost: Identifiable, Hashable, Sendable {
    public let address: IPv4Address
    public var hostname: String?
    public var bonjourName: String?
    public var macAddress: String?
    public var vendor: String?
    public var openPorts: [UInt16] = []
    public var latency: TimeInterval?
    public var evidence: Set<HostEvidence> = []
    public var services: [String] = []
    public var isLocalMachine = false
    public var isGateway = false

    public init(address: IPv4Address) {
        self.address = address
    }

    public var id: UInt32 { address.value }

    public var isAlive: Bool { !evidence.isEmpty }

    /// The best name available for display.
    public var displayName: String {
        if let bonjourName, !bonjourName.isEmpty { return bonjourName }
        if let hostname, !hostname.isEmpty { return hostname }
        return ""
    }

    public var macDisplay: String { macAddress ?? "" }

    public var vendorDisplay: String {
        if let vendor, !vendor.isEmpty { return vendor }
        if let macAddress, MACAddress.isLocallyAdministered(macAddress) { return "Private address" }
        return ""
    }

    public var portsSummary: String {
        openPorts.map { String($0) }.joined(separator: ", ")
    }

    public var latencyMilliseconds: Double {
        guard let latency else { return .greatestFiniteMagnitude }
        return latency * 1000
    }

    public var latencyText: String {
        guard let latency else { return "" }
        let ms = latency * 1000
        return ms < 1 ? "<1 ms" : String(format: "%.0f ms", ms)
    }

    public var roleText: String {
        if isLocalMachine { return "This Mac" }
        if isGateway { return "Router" }
        return ""
    }

    public var searchText: String {
        [address.description, displayName, macDisplay, vendorDisplay, portsSummary, services.joined(separator: " "), roleText]
            .joined(separator: " ")
    }
}

public struct ScanSettings: Sendable {
    public var probeTimeout: TimeInterval = 1.0
    public var maxConcurrentHosts = 32
    public var maxConcurrentProbes = 256
    public var discoveryPorts: [UInt16] = KnownPorts.discovery
    public var servicePorts: [UInt16] = KnownPorts.services
    public var resolveNames = true
    public var bonjourDuration: TimeInterval = 3.0
    public var localAddress: IPv4Address?
    public var localMAC: String?
    public var gateway: IPv4Address?

    public init() {}
}

public struct ScanSummary: Sendable, Equatable {
    public let addressesScanned: Int
    public let hostsFound: Int
    public let duration: TimeInterval
    public let wasCancelled: Bool

    public init(addressesScanned: Int, hostsFound: Int, duration: TimeInterval, wasCancelled: Bool) {
        self.addressesScanned = addressesScanned
        self.hostsFound = hostsFound
        self.duration = duration
        self.wasCancelled = wasCancelled
    }
}

public enum ScanEvent: Sendable {
    case phase(ScanPhase)
    case progress(Double)
    case status(String)
    case host(ScannedHost)
    case finished(ScanSummary)
}
