import Foundation

/// Reverse name lookup through the system resolver, which on macOS also
/// answers from multicast DNS for devices that advertise a .local name.
public enum ReverseDNS {
    public static func lookup(_ ip: IPv4Address) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: blockingLookup(ip))
            }
        }
    }

    static func blockingLookup(_ ip: IPv4Address) -> String? {
        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_addr.s_addr = ip.value.bigEndian

        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let status = withUnsafePointer(to: &socketAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                getnameinfo(
                    generic,
                    socklen_t(MemoryLayout<sockaddr_in>.size),
                    &buffer,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NAMEREQD
                )
            }
        }
        guard status == 0 else { return nil }
        let name = String(cString: buffer)
        guard !name.isEmpty, name != ip.description else { return nil }
        return name.hasSuffix(".") ? String(name.dropLast()) : name
    }
}
