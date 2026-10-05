import Foundation

/// Runs one scan and publishes its results as a stream of events.
///
/// Phases:
/// 1. Discovery: a handful of TCP ports per address. An open port or a reset
///    both prove a device is there.
/// 2. ARP: the kernel cache is read. Every address that answered ARP during
///    phase 1 is alive, with its hardware address, even if every port dropped
///    the probe.
/// 3. Services: a wider port list, only for addresses known to be alive.
/// 4. Names: Bonjour browsing and reverse DNS for the alive addresses.
public struct ScanRunner: Sendable {
    public let targets: [IPv4Address]
    public let settings: ScanSettings
    public let oui: OUIDatabase

    public init(targets: [IPv4Address], settings: ScanSettings, oui: OUIDatabase) {
        self.targets = targets
        self.settings = settings
        self.oui = oui
    }

    public func run() -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await self.execute(continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Pipeline

    private struct ProbeResult: Sendable {
        let address: IPv4Address
        let openPorts: [UInt16]
        let latency: TimeInterval?
        let responded: Bool
    }

    private func execute(_ out: AsyncStream<ScanEvent>.Continuation) async {
        let started = Date()
        let targetSet = Set(targets)
        let limiter = ProbeLimiter(settings.maxConcurrentProbes)
        var hosts: [UInt32: ScannedHost] = [:]

        func upsert(_ host: ScannedHost) {
            var host = host
            if let gateway = settings.gateway, host.address == gateway {
                host.isGateway = true
            }
            if let mac = host.macAddress, host.vendor == nil {
                host.vendor = oui.vendor(forMAC: mac)
            }
            hosts[host.id] = host
            out.yield(.host(host))
        }

        func merge(_ result: ProbeResult) {
            guard result.responded || !result.openPorts.isEmpty else { return }
            var host = hosts[result.address.value] ?? ScannedHost(address: result.address)
            host.openPorts = Array(Set(host.openPorts).union(result.openPorts)).sorted()
            if let latency = result.latency {
                host.latency = min(host.latency ?? latency, latency)
            }
            host.evidence.insert(.tcp)
            upsert(host)
        }

        if let local = settings.localAddress, targetSet.contains(local) {
            var host = ScannedHost(address: local)
            host.isLocalMachine = true
            host.macAddress = settings.localMAC
            host.hostname = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
            host.evidence.insert(.local)
            upsert(host)
        }

        // Phase 1: discovery.
        out.yield(.phase(.discovering))
        out.yield(.status("Probing \(targets.count) addresses"))
        var completed = 0
        let discoveryPorts = settings.discoveryPorts
        let timeout = settings.probeTimeout
        await withTaskGroup(of: ProbeResult.self) { group in
            var inFlight = 0
            for target in targets {
                if Task.isCancelled { break }
                if inFlight >= settings.maxConcurrentHosts, let result = await group.next() {
                    inFlight -= 1
                    completed += 1
                    merge(result)
                    out.yield(.progress(Double(completed) / Double(max(targets.count, 1)) * 0.6))
                }
                group.addTask {
                    await Self.probe(target, ports: discoveryPorts, timeout: timeout, limiter: limiter)
                }
                inFlight += 1
            }
            for await result in group {
                completed += 1
                merge(result)
                out.yield(.progress(Double(completed) / Double(max(targets.count, 1)) * 0.6))
            }
        }

        // Phase 2: ARP cache.
        if !Task.isCancelled {
            out.yield(.status("Reading the ARP cache"))
            let entries = await ARPTable.read()
            for entry in entries where targetSet.contains(entry.address) {
                var host = hosts[entry.address.value] ?? ScannedHost(address: entry.address)
                host.macAddress = entry.macAddress
                host.vendor = oui.vendor(forMAC: entry.macAddress)
                host.evidence.insert(.arp)
                upsert(host)
            }
        }

        // Phase 3: wider service probe on alive hosts only.
        let alive = hosts.values.filter(\.isAlive).map(\.address).sorted()
        let servicePorts = settings.servicePorts.filter { !settings.discoveryPorts.contains($0) }
        if !alive.isEmpty, !servicePorts.isEmpty, !Task.isCancelled {
            out.yield(.phase(.probingServices))
            out.yield(.status("Checking \(servicePorts.count) ports on \(alive.count) devices"))
            var done = 0
            await withTaskGroup(of: ProbeResult.self) { group in
                var inFlight = 0
                for address in alive {
                    if Task.isCancelled { break }
                    if inFlight >= settings.maxConcurrentHosts, let result = await group.next() {
                        inFlight -= 1
                        done += 1
                        merge(result)
                        out.yield(.progress(0.6 + Double(done) / Double(alive.count) * 0.25))
                    }
                    group.addTask {
                        await Self.probe(address, ports: servicePorts, timeout: timeout, limiter: limiter)
                    }
                    inFlight += 1
                }
                for await result in group {
                    done += 1
                    merge(result)
                    out.yield(.progress(0.6 + Double(done) / Double(alive.count) * 0.25))
                }
            }
        }

        // Phase 4: names.
        if settings.resolveNames, !Task.isCancelled {
            out.yield(.phase(.resolvingNames))
            out.yield(.status("Listening for Bonjour announcements"))
            let records = await BonjourDiscovery().discover(duration: settings.bonjourDuration)
            var namePriority: [UInt32: Int] = [:]
            for record in records {
                for address in record.addresses where targetSet.contains(address) {
                    var host = hosts[address.value] ?? ScannedHost(address: address)
                    let label = record.serviceLabel
                    if !host.services.contains(label) {
                        host.services.append(label)
                        host.services.sort()
                    }
                    if let name = record.deviceName,
                       record.namePriority < (namePriority[address.value] ?? Int.max) {
                        host.bonjourName = name
                        namePriority[address.value] = record.namePriority
                    }
                    host.evidence.insert(.bonjour)
                    upsert(host)
                }
            }
            out.yield(.progress(0.9))

            out.yield(.status("Looking up names"))
            let unnamed = hosts.values.filter { $0.isAlive && $0.hostname == nil }.map(\.address).sorted()
            await withTaskGroup(of: (IPv4Address, String?).self) { group in
                var inFlight = 0
                for address in unnamed {
                    if Task.isCancelled { break }
                    if inFlight >= 16, let pair = await group.next() {
                        inFlight -= 1
                        if let name = pair.1, var host = hosts[pair.0.value] {
                            host.hostname = name
                            upsert(host)
                        }
                    }
                    group.addTask {
                        let name = await ReverseDNS.lookup(address)
                        return (address, name)
                    }
                    inFlight += 1
                }
                for await pair in group {
                    if let name = pair.1, var host = hosts[pair.0.value] {
                        host.hostname = name
                        upsert(host)
                    }
                }
            }
        }

        out.yield(.progress(1))
        let summary = ScanSummary(
            addressesScanned: completed,
            hostsFound: hosts.values.filter(\.isAlive).count,
            duration: Date().timeIntervalSince(started),
            wasCancelled: Task.isCancelled
        )
        out.yield(.finished(summary))
        out.yield(.phase(Task.isCancelled ? .cancelled : .finished))
    }

    private static func probe(_ address: IPv4Address, ports: [UInt16], timeout: TimeInterval, limiter: ProbeLimiter) async -> ProbeResult {
        var open: [UInt16] = []
        var best: TimeInterval?
        var responded = false
        await withTaskGroup(of: (UInt16, PortState).self) { group in
            for port in ports {
                group.addTask {
                    if Task.isCancelled { return (port, .filtered) }
                    await limiter.acquire()
                    let state = await PortProbe.probe(host: address, port: port, timeout: timeout)
                    await limiter.release()
                    return (port, state)
                }
            }
            for await (port, state) in group {
                switch state {
                case .open(let latency):
                    open.append(port)
                    responded = true
                    best = min(best ?? latency, latency)
                case .closed:
                    responded = true
                case .filtered, .unreachable:
                    break
                }
            }
        }
        return ProbeResult(address: address, openPorts: open.sorted(), latency: best, responded: responded)
    }
}
