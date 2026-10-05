import Foundation

/// An IPv4 address stored as a host-order 32-bit integer.
public struct IPv4Address: Hashable, Comparable, CustomStringConvertible, Sendable, Codable {
    public let value: UInt32

    public init(_ value: UInt32) {
        self.value = value
    }

    /// Parses dotted-quad notation such as "192.168.1.10".
    public init?(_ text: String) {
        let parts = text
            .trimmingCharacters(in: .whitespaces)
            .split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var result: UInt32 = 0
        for part in parts {
            guard !part.isEmpty,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let octet = UInt8(part) else { return nil }
            result = (result << 8) | UInt32(octet)
        }
        self.value = result
    }

    public var octets: [UInt8] {
        [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
    }

    public var description: String {
        octets.map { String($0) }.joined(separator: ".")
    }

    /// 169.254.0.0/16
    public var isLinkLocal: Bool { (value & 0xffff_0000) == 0xa9fe_0000 }
    /// 127.0.0.0/8
    public var isLoopback: Bool { (value & 0xff00_0000) == 0x7f00_0000 }
    /// 224.0.0.0/4
    public var isMulticast: Bool { (value & 0xf000_0000) == 0xe000_0000 }

    public static func < (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
        lhs.value < rhs.value
    }
}

/// An IPv4 network in CIDR form, e.g. 192.168.1.0/24.
public struct IPv4Network: Hashable, CustomStringConvertible, Sendable {
    public let address: IPv4Address
    public let prefixLength: Int

    public init(address: IPv4Address, prefixLength: Int) {
        let prefix = min(max(prefixLength, 0), 32)
        self.prefixLength = prefix
        self.address = IPv4Address(address.value & IPv4Network.mask(prefixLength: prefix))
    }

    public init?(cidr: String) {
        let pieces = cidr.trimmingCharacters(in: .whitespaces).split(separator: "/")
        guard pieces.count == 2,
              let address = IPv4Address(String(pieces[0])),
              let prefix = Int(pieces[1]),
              (0...32).contains(prefix) else { return nil }
        self.init(address: address, prefixLength: prefix)
    }

    public static func mask(prefixLength: Int) -> UInt32 {
        if prefixLength <= 0 { return 0 }
        if prefixLength >= 32 { return UInt32.max }
        return UInt32.max << UInt32(32 - prefixLength)
    }

    /// Assumes a contiguous netmask.
    public static func prefixLength(mask: UInt32) -> Int {
        mask.nonzeroBitCount
    }

    public var mask: UInt32 { IPv4Network.mask(prefixLength: prefixLength) }

    public var broadcast: IPv4Address { IPv4Address(address.value | ~mask) }

    public func contains(_ ip: IPv4Address) -> Bool {
        (ip.value & mask) == address.value
    }

    /// Number of addresses worth probing. Network and broadcast addresses are
    /// excluded for prefixes shorter than /31.
    public var hostCount: Int {
        if prefixLength >= 31 { return Int(broadcast.value - address.value) + 1 }
        return max(Int(broadcast.value - address.value) - 1, 0)
    }

    public var hostAddresses: [IPv4Address] {
        if prefixLength >= 31 {
            return (address.value...broadcast.value).map { IPv4Address($0) }
        }
        guard broadcast.value > address.value + 1 else { return [] }
        return ((address.value + 1)...(broadcast.value - 1)).map { IPv4Address($0) }
    }

    public var description: String { "\(address)/\(prefixLength)" }
}

public enum ScanRangeError: Error, LocalizedError, Equatable {
    case empty
    case invalidFormat(String)
    case tooLarge(count: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a range to scan, for example 192.168.1.0/24."
        case .invalidFormat(let text):
            return "\"\(text)\" is not a valid range. Use CIDR (192.168.1.0/24), a dash range (192.168.1.1-254) or a single address."
        case .tooLarge(let count, let limit):
            return "That range contains \(count) addresses. The limit is \(limit)."
        }
    }
}

/// Parses the text a user types into the range field.
public enum ScanRange {
    public static let maximumAddresses = 65_536

    /// Accepts "10.0.0.0/24", "10.0.0.1-254", "10.0.0.1-10.0.0.254" or "10.0.0.5".
    public static func parse(_ text: String) throws -> [IPv4Address] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ScanRangeError.empty }

        if trimmed.contains("/") {
            guard let network = IPv4Network(cidr: trimmed) else {
                throw ScanRangeError.invalidFormat(trimmed)
            }
            guard network.hostCount <= maximumAddresses else {
                throw ScanRangeError.tooLarge(count: network.hostCount, limit: maximumAddresses)
            }
            return network.hostAddresses
        }

        if let dash = trimmed.firstIndex(of: "-") {
            let startText = String(trimmed[..<dash]).trimmingCharacters(in: .whitespaces)
            let endText = String(trimmed[trimmed.index(after: dash)...]).trimmingCharacters(in: .whitespaces)
            guard let start = IPv4Address(startText) else {
                throw ScanRangeError.invalidFormat(trimmed)
            }
            let end: IPv4Address
            if let full = IPv4Address(endText) {
                end = full
            } else if let lastOctet = UInt8(endText) {
                end = IPv4Address((start.value & 0xffff_ff00) | UInt32(lastOctet))
            } else {
                throw ScanRangeError.invalidFormat(trimmed)
            }
            guard end.value >= start.value else {
                throw ScanRangeError.invalidFormat(trimmed)
            }
            let count = Int(end.value - start.value) + 1
            guard count <= maximumAddresses else {
                throw ScanRangeError.tooLarge(count: count, limit: maximumAddresses)
            }
            return (start.value...end.value).map { IPv4Address($0) }
        }

        guard let single = IPv4Address(trimmed) else {
            throw ScanRangeError.invalidFormat(trimmed)
        }
        return [single]
    }
}
