import Foundation

public enum CSVExporter {
    public static let header = ["IP address", "Name", "MAC address", "Vendor", "Open ports", "Services", "Latency (ms)", "Role", "Evidence"]

    public static func csv(for hosts: [ScannedHost]) -> String {
        var lines = [CSV.line(header)]
        for host in hosts.sorted(by: { $0.address < $1.address }) {
            let latency = host.latency.map { String(format: "%.1f", $0 * 1000) } ?? ""
            lines.append(CSV.line([
                host.address.description,
                host.displayName,
                host.macDisplay,
                host.vendorDisplay,
                host.openPorts.map { KnownPorts.label(for: $0) }.joined(separator: "; "),
                host.services.joined(separator: "; "),
                latency,
                host.roleText,
                host.evidence.sorted().map(\.rawValue).joined(separator: "; "),
            ]))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
