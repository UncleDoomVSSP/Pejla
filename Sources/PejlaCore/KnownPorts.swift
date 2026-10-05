import Foundation

public enum KnownPorts {
    /// A small, fast set used to decide whether anything is at an address.
    public static let discovery: [UInt16] = [
        22, 53, 80, 139, 443, 445, 548, 3389, 5000, 7000, 8080, 62078,
    ]

    /// A broader set probed only on addresses that are known to be up.
    public static let services: [UInt16] = [
        21, 22, 23, 25, 53, 80, 81, 88, 110, 111, 135, 139, 143, 443, 445, 515, 548,
        554, 587, 631, 993, 995, 1883, 2049, 3000, 3306, 3389, 5000, 5001, 5060,
        5432, 5900, 5901, 6379, 7000, 7100, 8000, 8008, 8080, 8081, 8123, 8443,
        8883, 8888, 9000, 9090, 9100, 10000, 32400, 49152, 49153, 62078,
    ]

    public static let names: [UInt16: String] = [
        21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS", 80: "HTTP", 81: "HTTP alt",
        88: "Kerberos", 110: "POP3", 111: "RPC", 135: "MS RPC", 139: "NetBIOS", 143: "IMAP",
        443: "HTTPS", 445: "SMB", 515: "LPD", 548: "AFP", 554: "RTSP", 587: "SMTP submission",
        631: "IPP printing", 993: "IMAPS", 995: "POP3S", 1883: "MQTT", 2049: "NFS",
        3000: "HTTP dev", 3306: "MySQL", 3389: "Remote Desktop", 5000: "UPnP / AirPlay",
        5001: "Synology DSM", 5060: "SIP", 5432: "PostgreSQL", 5900: "VNC / Screen Sharing",
        5901: "VNC", 6379: "Redis", 7000: "AirPlay", 7100: "AirPlay", 8000: "HTTP alt",
        8008: "Chromecast", 8080: "HTTP proxy", 8081: "HTTP alt", 8123: "Home Assistant",
        8443: "HTTPS alt", 8883: "MQTT TLS", 8888: "HTTP alt", 9000: "HTTP alt",
        9090: "HTTP alt", 9100: "Printer raw", 10000: "Webmin", 32400: "Plex",
        49152: "UPnP", 49153: "UPnP", 62078: "iOS sync",
    ]

    public static func name(for port: UInt16) -> String? {
        names[port]
    }

    public static func label(for port: UInt16) -> String {
        if let name = names[port] {
            return "\(port) \(name)"
        }
        return String(port)
    }
}
