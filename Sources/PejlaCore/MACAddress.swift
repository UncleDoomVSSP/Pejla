import Foundation

public enum MACAddress {
    /// Normalises a MAC address to lower-case, colon separated, zero padded form.
    /// macOS's `arp` prints octets without leading zeros ("0:1e:c2:..."), so
    /// padding is required before the address can be compared or looked up.
    public static func normalise(_ text: String) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "-", with: ":")
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 6 else { return nil }
        var octets: [String] = []
        for part in parts {
            guard part.count >= 1, part.count <= 2, let value = UInt8(part, radix: 16) else { return nil }
            octets.append(String(format: "%02x", value))
        }
        return octets.joined(separator: ":")
    }

    /// True when the locally administered bit is set, which is what Apple,
    /// Android and Windows do for randomised Wi-Fi addresses.
    public static func isLocallyAdministered(_ mac: String) -> Bool {
        guard let first = mac.split(separator: ":").first, let value = UInt8(first, radix: 16) else {
            return false
        }
        return value & 0x02 != 0
    }

    public static func isBroadcast(_ mac: String) -> Bool {
        mac == "ff:ff:ff:ff:ff:ff"
    }

    /// The 24-bit organisationally unique identifier as six upper-case hex digits.
    public static func oui(_ mac: String) -> String {
        mac.split(separator: ":").prefix(3).joined().uppercased()
    }
}
