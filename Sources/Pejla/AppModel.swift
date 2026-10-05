import Foundation
import Combine
import PejlaCore

enum SettingsKey {
    static let probeTimeoutMs = "probeTimeoutMs"
    static let thoroughPorts = "thoroughPorts"
    static let resolveNames = "resolveNames"
    static let bonjourSeconds = "bonjourSeconds"
}

/// Application state that is not part of a single scan: interfaces, the
/// range being edited and the vendor database.
@MainActor
final class AppModel: ObservableObject {
    let scanner = ScanController()

    @Published var interfaces: [NetworkInterface] = []
    @Published var selectedInterfaceID: String? {
        didSet {
            guard oldValue != selectedInterfaceID, let interface = selectedInterface else { return }
            rangeText = interface.network.description
        }
    }
    @Published var rangeText = ""
    @Published var gateway: IPv4Address?
    @Published var errorMessage: String?
    @Published private(set) var oui: OUIDatabase = .builtIn

    private var cancellables: Set<AnyCancellable> = []

    init() {
        refreshInterfaces()
        scanner.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        Task { [weak self] in
            let database = await Task.detached(priority: .utility) { OUIDatabase.preferred() }.value
            self?.oui = database
        }
    }

    var selectedInterface: NetworkInterface? {
        interfaces.first { $0.id == selectedInterfaceID }
    }

    var canScan: Bool {
        !rangeText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func refreshInterfaces() {
        interfaces = NetworkInterfaces.list()
        let route = NetworkInterfaces.defaultGateway()
        gateway = route?.router
        if let current = selectedInterfaceID, interfaces.contains(where: { $0.id == current }) {
            return
        }
        let preferred = interfaces.first { interface in
            if let router = route?.router, interface.network.contains(router) { return true }
            return interface.name == route?.interface
        } ?? interfaces.first
        selectedInterfaceID = preferred?.id
        if preferred == nil {
            rangeText = ""
        }
    }

    func startScan() {
        errorMessage = nil
        let targets: [IPv4Address]
        do {
            targets = try ScanRange.parse(rangeText)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        var settings = ScanSettings()
        let defaults = UserDefaults.standard
        let timeoutMs = defaults.integer(forKey: SettingsKey.probeTimeoutMs)
        settings.probeTimeout = timeoutMs > 0 ? Double(timeoutMs) / 1000 : 1.0
        if defaults.object(forKey: SettingsKey.thoroughPorts) != nil, !defaults.bool(forKey: SettingsKey.thoroughPorts) {
            settings.servicePorts = []
        }
        if defaults.object(forKey: SettingsKey.resolveNames) != nil {
            settings.resolveNames = defaults.bool(forKey: SettingsKey.resolveNames)
        }
        let bonjourSeconds = defaults.double(forKey: SettingsKey.bonjourSeconds)
        if bonjourSeconds > 0 {
            settings.bonjourDuration = bonjourSeconds
        }
        if let interface = selectedInterface {
            settings.localAddress = interface.address
            settings.localMAC = interface.macAddress
        }
        settings.gateway = gateway
        scanner.start(targets: targets, settings: settings, oui: oui)
    }

    func toggleScan() {
        if scanner.isScanning {
            scanner.stop()
        } else {
            startScan()
        }
    }
}
