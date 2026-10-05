import Foundation
import Network

public enum PortState: Sendable, Equatable {
    /// The TCP handshake completed.
    case open(latency: TimeInterval)
    /// The host answered with a reset, so it is up but nothing listens there.
    case closed
    /// No answer before the deadline.
    case filtered
    /// The kernel could not reach the host at all (no ARP reply, no route).
    case unreachable

    /// True when the response proves a device exists at the address.
    public var provesHostIsUp: Bool {
        switch self {
        case .open, .closed: return true
        case .filtered, .unreachable: return false
        }
    }
}

/// Bounds the number of sockets open at once so a large range cannot exhaust
/// file descriptors or flood the network.
public actor ProbeLimiter {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(_ permits: Int) {
        self.permits = max(permits, 1)
    }

    public func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func release() {
        if waiters.isEmpty {
            permits += 1
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}

/// Guarantees a continuation is resumed exactly once.
final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

public enum PortProbe {
    private static let queue = DispatchQueue(label: "se.pejla.probe", qos: .userInitiated, attributes: .concurrent)

    /// Attempts a TCP connection and classifies the outcome.
    public static func probe(host: IPv4Address, port: UInt16, timeout: TimeInterval) async -> PortState {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return .filtered }
        return await withCheckedContinuation { (continuation: CheckedContinuation<PortState, Never>) in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host.description), port: nwPort)
            let parameters = NWParameters.tcp
            if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
                tcp.connectionTimeout = max(1, Int(timeout.rounded(.up)))
                tcp.noDelay = true
            }
            let connection = NWConnection(to: endpoint, using: parameters)
            let started = Date()
            let gate = CompletionGate()

            func finish(_ state: PortState) {
                guard gate.claim() else { return }
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: state)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.open(latency: Date().timeIntervalSince(started)))
                case .failed(let error):
                    finish(classify(error))
                case .waiting(let error):
                    // Network.framework parks refused or unreachable connections in
                    // .waiting and retries; for a scanner the first answer is final.
                    finish(classify(error))
                case .cancelled:
                    finish(.filtered)
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.filtered)
            }
        }
    }

    static func classify(_ error: NWError) -> PortState {
        if case .posix(let code) = error {
            switch code {
            case .ECONNREFUSED, .ECONNRESET:
                return .closed
            case .EHOSTUNREACH, .EHOSTDOWN, .ENETUNREACH, .ENETDOWN, .EADDRNOTAVAIL:
                return .unreachable
            default:
                return .filtered
            }
        }
        return .filtered
    }
}
