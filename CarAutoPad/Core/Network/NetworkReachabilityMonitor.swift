import Foundation
import Network

extension Notification.Name {
    public static let carAutoPadNetworkReachabilityDidChange = Notification.Name("carAutoPadNetworkReachabilityDidChange")
}

public struct NetworkReachabilitySnapshot: Equatable, Sendable {
    public let isWifiConnected: Bool
    public let stationIpv4: String?
    public let gatewayIpv4: String?

    public init(isWifiConnected: Bool, stationIpv4: String?, gatewayIpv4: String?) {
        self.isWifiConnected = isWifiConnected
        self.stationIpv4 = stationIpv4
        self.gatewayIpv4 = gatewayIpv4
    }
}

public final class NetworkReachabilityMonitor: @unchecked Sendable {
    public static let shared = NetworkReachabilityMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.carautopad.network.reachability", qos: .utility)
    private var debounceItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.30
    private let lock = NSLock()

    private var _currentSnapshot: NetworkReachabilitySnapshot
    public var currentSnapshot: NetworkReachabilitySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return _currentSnapshot
    }

    private var isMonitoring = false

    public init() {
        self.monitor = NWPathMonitor()
        let initialStation = NetworkAddresses.stationIpv4()
        let initialGateway = initialStation != nil ? NetworkAddresses.currentHotspotGatewayIpv4() : nil
        self._currentSnapshot = NetworkReachabilitySnapshot(
            isWifiConnected: initialStation != nil,
            stationIpv4: initialStation,
            gatewayIpv4: initialGateway
        )
    }

    public func start() {
        lock.lock()
        guard !isMonitoring else {
            lock.unlock()
            return
        }
        isMonitoring = true
        lock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            self?.scheduleEvaluation(path: path)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        guard isMonitoring else {
            lock.unlock()
            return
        }
        isMonitoring = false
        debounceItem?.cancel()
        debounceItem = nil
        lock.unlock()

        monitor.cancel()
    }

    private func scheduleEvaluation(path: NWPath) {
        lock.lock()
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.performEvaluation(path: path)
        }
        debounceItem = item
        lock.unlock()

        queue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    @discardableResult
    public func evaluateNow() -> NetworkReachabilitySnapshot {
        return performEvaluation(path: monitor.currentPath)
    }

    @discardableResult
    private func performEvaluation(path: NWPath) -> NetworkReachabilitySnapshot {
        let station = NetworkAddresses.stationIpv4()
        let hasWifiInterface = station != nil
        let gateway = hasWifiInterface ? NetworkAddresses.currentHotspotGatewayIpv4() : nil

        let newSnapshot = NetworkReachabilitySnapshot(
            isWifiConnected: hasWifiInterface,
            stationIpv4: station,
            gatewayIpv4: gateway
        )

        lock.lock()
        let previous = _currentSnapshot
        _currentSnapshot = newSnapshot
        lock.unlock()

        if hasWifiInterface {
            ConnectionIssueStore.shared.clear(issue: .wifiRadioOff)
        } else {
            ConnectionIssueStore.shared.raise(issue: .wifiRadioOff)
        }

        if previous != newSnapshot {
            AppLog.i("Network reachability changed: wifi=\(newSnapshot.isWifiConnected) station=\(newSnapshot.stationIpv4 ?? "none") gateway=\(newSnapshot.gatewayIpv4 ?? "none")", tag: "NetworkMonitor")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .carAutoPadNetworkReachabilityDidChange,
                    object: self,
                    userInfo: [
                        "snapshot": newSnapshot,
                        "stationIpv4": newSnapshot.stationIpv4 as Any,
                        "gatewayIpv4": newSnapshot.gatewayIpv4 as Any
                    ]
                )
            }
        }

        return newSnapshot
    }
}
