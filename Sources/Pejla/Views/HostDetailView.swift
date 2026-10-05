import SwiftUI
import PejlaCore

struct HostDetailView: View {
    let host: ScannedHost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.displayName.isEmpty ? host.address.description : host.displayName)
                        .font(.title2)
                        .bold()
                        .textSelection(.enabled)
                    if !host.displayName.isEmpty {
                        Text(host.address.description)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    if !host.roleText.isEmpty {
                        Text(host.roleText)
                            .font(.caption)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }

                Divider()

                detailRow("Hostname", host.hostname)
                detailRow("Bonjour name", host.bonjourName)
                detailRow("MAC address", host.macAddress)
                detailRow("Vendor", host.vendorDisplay)
                detailRow("Latency", host.latencyText)

                section("Open ports") {
                    if host.openPorts.isEmpty {
                        Text("None found").foregroundStyle(.secondary)
                    } else {
                        ForEach(host.openPorts, id: \.self) { port in
                            Text(KnownPorts.label(for: port)).textSelection(.enabled)
                        }
                    }
                }

                if !host.services.isEmpty {
                    section("Bonjour services") {
                        ForEach(host.services, id: \.self) { service in
                            Text(service)
                        }
                    }
                }

                section("How it was found") {
                    ForEach(host.evidence.sorted(), id: \.self) { evidence in
                        Label(evidence.title, systemImage: "checkmark.circle")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HostActions(host: host)
                }
                .controlSize(.small)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .textSelection(.enabled)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// Actions that make sense for a device, shown both in the detail panel and
/// in the table's context menu.
struct HostActions: View {
    let host: ScannedHost
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Copy IP Address") { Pasteboard.copy(host.address.description) }
        if let mac = host.macAddress {
            Button("Copy MAC Address") { Pasteboard.copy(mac) }
        }
        if let web = webURL {
            Button("Open in Browser") { openURL(web) }
        }
        if host.openPorts.contains(22), let url = URL(string: "ssh://\(host.address)") {
            Button("Connect with SSH") { openURL(url) }
        }
        if host.openPorts.contains(5900), let url = URL(string: "vnc://\(host.address)") {
            Button("Share Screen") { openURL(url) }
        }
        if host.openPorts.contains(445), let url = URL(string: "smb://\(host.address)") {
            Button("Connect to Shared Files") { openURL(url) }
        }
    }

    private var webURL: URL? {
        let candidates: [(UInt16, String)] = [(443, "https"), (80, "http"), (8443, "https"), (8080, "http"), (8123, "http"), (5000, "http"), (32400, "http")]
        for (port, scheme) in candidates where host.openPorts.contains(port) {
            let suffix = (port == 80 || port == 443) ? "" : ":\(port)"
            return URL(string: "\(scheme)://\(host.address)\(suffix)/")
        }
        return nil
    }
}
