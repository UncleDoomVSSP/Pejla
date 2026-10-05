import SwiftUI
import PejlaCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var scanner: ScanController
    @State private var selection: ScannedHost.ID?
    @State private var sortOrder: [KeyPathComparator<ScannedHost>] = [KeyPathComparator(\ScannedHost.address)]
    @State private var filter = ""

    private var visibleHosts: [ScannedHost] {
        let alive = scanner.aliveHosts
        let filtered = filter.isEmpty ? alive : alive.filter { $0.searchText.localizedCaseInsensitiveContains(filter) }
        return filtered.sorted(using: sortOrder)
    }

    private var subtitle: String {
        guard let interface = model.selectedInterface else { return "No network interface" }
        return "\(interface.displayName) - \(interface.network.description)"
    }

    private var selectedHost: ScannedHost? {
        guard let selection else { return nil }
        return scanner.hosts.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let message = model.errorMessage {
                errorBanner(message)
                Divider()
            }
            HStack(spacing: 0) {
                hostTable
                if let host = selectedHost {
                    Divider()
                    HostDetailView(host: host)
                        .frame(width: 320)
                }
            }
            Divider()
            StatusBar(scanner: scanner)
        }
        .toolbar { toolbarContent }
        .searchable(text: $filter, placement: .toolbar, prompt: "Filter devices")
        .navigationTitle("Pejla")
        .navigationSubtitle(subtitle)
    }

    private var hostTable: some View {
        Table(visibleHosts, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Address", value: \.address) { host in
                HStack(spacing: 6) {
                    Circle()
                        .fill(HostStatus.colour(for: host))
                        .frame(width: 8, height: 8)
                        .help(HostStatus.description(for: host))
                    Text(host.address.description)
                        .monospacedDigit()
                    if !host.roleText.isEmpty {
                        Text(host.roleText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 150, ideal: 180)

            TableColumn("Name", value: \.displayName)
                .width(min: 120, ideal: 200)

            TableColumn("MAC address", value: \.macDisplay) { host in
                Text(host.macDisplay).monospaced()
            }
            .width(min: 130, ideal: 140)

            TableColumn("Vendor", value: \.vendorDisplay)
                .width(min: 120, ideal: 180)

            TableColumn("Open ports", value: \.portsSummary)
                .width(min: 100, ideal: 200)

            TableColumn("Latency", value: \.latencyMilliseconds) { host in
                Text(host.latencyText).monospacedDigit()
            }
            .width(min: 60, ideal: 70)
        }
        .contextMenu(forSelectionType: ScannedHost.ID.self) { ids in
            if let id = ids.first, let host = scanner.hosts.first(where: { $0.id == id }) {
                HostActions(host: host)
            }
        }
        .overlay {
            if visibleHosts.isEmpty {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: scanner.isScanning ? "dot.radiowaves.left.and.right" : "network")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            if scanner.isScanning {
                Text("Looking for devices...")
                    .font(.title3)
            } else if !filter.isEmpty {
                Text("No devices match \"\(filter)\"")
                    .font(.title3)
            } else if scanner.phase == .finished || scanner.phase == .cancelled {
                Text("No devices found")
                    .font(.title3)
                Text("Nothing answered on \(model.rangeText). If macOS asked whether Pejla may find devices on the local network and the answer was no, allow it in System Settings > Privacy & Security > Local Network, then scan again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)
            } else {
                Text("Ready to scan")
                    .font(.title3)
                Text("Press Scan to list the devices on \(model.rangeText.isEmpty ? "your network" : model.rangeText).")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
            Spacer()
            Button("Dismiss") { model.errorMessage = nil }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.12))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Interface", selection: $model.selectedInterfaceID) {
                ForEach(model.interfaces) { interface in
                    Text(interface.label).tag(Optional(interface.id))
                }
            }
            .labelsHidden()
            .frame(minWidth: 220)
            .help("Network interface to scan")
            .disabled(scanner.isScanning)
        }
        ToolbarItem(placement: .principal) {
            TextField("Range", text: $model.rangeText, prompt: Text("192.168.1.0/24"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)
                .onSubmit { model.startScan() }
                .help("CIDR (192.168.1.0/24), a dash range (192.168.1.1-254) or a single address")
                .disabled(scanner.isScanning)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { model.toggleScan() } label: {
                Label(scanner.isScanning ? "Stop" : "Scan", systemImage: scanner.isScanning ? "stop.fill" : "play.fill")
            }
            .help(scanner.isScanning ? "Stop the scan" : "Scan the range")
            .disabled(!scanner.isScanning && !model.canScan)
        }
        ToolbarItem {
            Button { Exporter.exportCSV(scanner.aliveHosts) } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export the results as CSV")
            .disabled(scanner.aliveHosts.isEmpty)
        }
        ToolbarItem {
            Button { model.refreshInterfaces() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh the list of network interfaces")
            .disabled(scanner.isScanning)
        }
    }
}

enum HostStatus {
    static func colour(for host: ScannedHost) -> Color {
        if host.isLocalMachine { return .blue }
        if host.evidence.contains(.tcp) || host.evidence.contains(.bonjour) { return .green }
        if host.evidence.contains(.arp) { return .orange }
        return .gray
    }

    static func description(for host: ScannedHost) -> String {
        if host.isLocalMachine { return "This Mac" }
        if host.evidence.contains(.tcp) || host.evidence.contains(.bonjour) { return "Responded to probes" }
        if host.evidence.contains(.arp) { return "Seen on the network (hardware address only)" }
        return "Unknown"
    }
}

struct StatusBar: View {
    @ObservedObject var scanner: ScanController

    var body: some View {
        HStack(spacing: 12) {
            if scanner.isScanning {
                ProgressView(value: scanner.progress)
                    .frame(width: 160)
                Text(scanner.status.isEmpty ? scanner.phase.title : "\(scanner.phase.title): \(scanner.status)")
            } else if let summary = scanner.summary {
                Text(summaryText(summary))
            } else {
                Text("Ready")
            }
            Spacer()
            legend
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(.green, "Responded")
            legendItem(.orange, "Hardware address only")
            legendItem(.blue, "This Mac")
        }
        .font(.caption)
    }

    private func legendItem(_ colour: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(colour).frame(width: 7, height: 7)
            Text(title)
        }
    }

    private func summaryText(_ summary: ScanSummary) -> String {
        let devices = summary.hostsFound == 1 ? "1 device" : "\(summary.hostsFound) devices"
        let seconds = String(format: "%.0f", summary.duration)
        let prefix = summary.wasCancelled ? "Stopped. " : ""
        return "\(prefix)\(devices) found. \(summary.addressesScanned) addresses scanned in \(seconds) s."
    }
}
