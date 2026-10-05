import Foundation
import Combine

/// Owns the current scan and exposes its state to SwiftUI.
@MainActor
public final class ScanController: ObservableObject {
    @Published public private(set) var hosts: [ScannedHost] = []
    @Published public private(set) var phase: ScanPhase = .idle
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var status: String = ""
    @Published public private(set) var summary: ScanSummary?
    @Published public private(set) var isScanning = false
    @Published public var lastTargetCount = 0

    private var hostIndex: [UInt32: Int] = [:]
    private var task: Task<Void, Never>?
    private var generation = 0

    public init() {}

    public func start(targets: [IPv4Address], settings: ScanSettings, oui: OUIDatabase) {
        stop()
        hosts = []
        hostIndex = [:]
        progress = 0
        summary = nil
        status = ""
        lastTargetCount = targets.count
        isScanning = true
        generation += 1
        let current = generation
        let runner = ScanRunner(targets: targets, settings: settings, oui: oui)
        task = Task { [weak self] in
            for await event in runner.run() {
                guard let self, self.generation == current else { return }
                self.apply(event)
            }
            guard let self, self.generation == current else { return }
            self.isScanning = false
            self.task = nil
            if self.phase.isActive {
                self.phase = .cancelled
            }
        }
    }

    public func stop() {
        guard let running = task else { return }
        running.cancel()
        task = nil
        isScanning = false
        if phase.isActive {
            phase = .cancelled
        }
    }

    public var aliveHosts: [ScannedHost] {
        hosts.filter(\.isAlive)
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .phase(let newPhase):
            phase = newPhase
        case .progress(let value):
            progress = min(max(value, 0), 1)
        case .status(let text):
            status = text
        case .host(let host):
            if let index = hostIndex[host.id] {
                hosts[index] = host
            } else {
                hostIndex[host.id] = hosts.count
                hosts.append(host)
            }
        case .finished(let result):
            summary = result
        }
    }
}
