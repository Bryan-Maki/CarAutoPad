import Foundation
import AVFoundation
import Network
import UIKit

enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case waitingForWirelessHelper
    case connecting
    case handshaking
    case running
    case disconnecting
    case error(String)

    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .discovering:
            return "Scanning..."
        case .waitingForWirelessHelper:
            return "Waiting for Wireless Helper / WPP..."
        case .connecting:
            return "Connecting..."
        case .handshaking:
            return "Handshaking..."
        case .running:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var localizedDescription: String {
        switch self {
        case .disconnected:
            return L10n.stateDisconnected
        case .discovering:
            return L10n.stateDiscovering
        case .waitingForWirelessHelper:
            return L10n.stateWaitingHelper
        case .connecting:
            return L10n.stateConnecting
        case .handshaking:
            return L10n.stateHandshaking
        case .running:
            return L10n.stateConnected
        case .disconnecting:
            return L10n.stateDisconnecting
        case .error(let message):
            return L10n.stateError(message)
        }
    }
}

public enum ConnectionStatusKind: Equatable {
    case ready
    case searchFailedNoWifi
    case scanning(stationIp: String)
    case connecting(deviceName: String)
    case retrying(attempt: Int, maxAttempts: Int)
    case failedAfterRetries(maxAttempts: Int)
    case noDeviceFound
    case searchFailed(reason: String)
    case waitingForHeadunitServer
    case handshakingTls
    case runningWireless
    case disconnectedFromSession
    case handshakeVersionTimeout
    case tlsHandshakeTimeout
    case customError(String)

    public var isDisconnectedWarning: Bool {
        switch self {
        case .searchFailedNoWifi, .noDeviceFound, .searchFailed, .failedAfterRetries:
            return true
        default:
            return false
        }
    }

    public var localizedText: String {
        switch self {
        case .ready:
            return L10n.statusReadyToConnect
        case .searchFailedNoWifi:
            return L10n.statusSearchFailedNoWifi
        case .scanning(let stationIp):
            return L10n.statusScanning(stationIp: stationIp)
        case .connecting(let deviceName):
            return L10n.statusConnectingTo(deviceName)
        case .retrying(let attempt, let maxAttempts):
            return L10n.statusRetrying(attempt: attempt, maxAttempts: maxAttempts)
        case .failedAfterRetries(let maxAttempts):
            return L10n.statusFailedAfterRetries(maxAttempts)
        case .noDeviceFound:
            return L10n.statusNoDeviceFound
        case .searchFailed(let reason):
            return L10n.statusSearchFailed(reason: reason)
        case .waitingForHeadunitServer:
            return L10n.statusWaitingHeadunitServer
        case .handshakingTls:
            return L10n.statusHandshakingTls
        case .runningWireless:
            return L10n.statusRunningWireless
        case .disconnectedFromSession:
            return L10n.statusDisconnectedFromSession
        case .handshakeVersionTimeout:
            return L10n.statusHandshakeVersionTimeout
        case .tlsHandshakeTimeout:
            return L10n.statusTlsHandshakeTimeout
        case .customError(let message):
            return message
        }
    }
}

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangeState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didUpdateStatus status: String)
    func connectionManager(_ manager: ConnectionManager, didDiscoverDevice device: DiscoveredDevice)
    func connectionManager(_ manager: ConnectionManager, didReceiveVideoData data: Data)
    func connectionManager(_ manager: ConnectionManager, didReceiveAudioData data: Data, on channel: UInt8)
    func connectionManager(_ manager: ConnectionManager, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool)
    func connectionManager(_ manager: ConnectionManager, didReceiveAudioCodecConfig data: Data, on channel: UInt8)
    func connectionManagerDidEnterBackground(_ manager: ConnectionManager)
    func connectionManagerWillEnterForeground(_ manager: ConnectionManager)
}

extension ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool) {
        connectionManager(manager, didReceiveAudioData: data, on: channel)
    }
    func connectionManager(_ manager: ConnectionManager, didReceiveAudioCodecConfig data: Data, on channel: UInt8) {}
    func connectionManagerDidEnterBackground(_ manager: ConnectionManager) {}
    func connectionManagerWillEnterForeground(_ manager: ConnectionManager) {}
}

class ConnectionManager {
    static let shared = ConnectionManager()
    weak var delegate: ConnectionManagerDelegate?

    public var screenConfig: HeadUnitScreenConfig {
        return HeadUnitScreenConfig.shared
    }

    private let discovery = Discovery()
    private let tcpHandler = TcpHandler()
    private let arbiter = ConnectionArbiter()
    private let playbackSnapshot = ReconnectPlaybackSnapshot()
    private let microphoneCapture = MicrophoneCapture()
    private let locationCapture = LocationCapture()

    private var aapTransport: AapTransport?
    private var activeConnection: ByteStreamConnection?
    private var isUserInitiatedDisconnect = false
    private var hasReceivedAaMediaMetadata = false
    private var lastPlayingState: Bool = false
    private var consecutiveStarvedSessions: Int = 0
    private var consecutiveSilentFailures: Int = 0
    private var lastTriedEndpoint: String?
    private var backgroundEnteredUptime: TimeInterval = 0
    private var foregroundWatchdogWorkItem: DispatchWorkItem?
    private var delayedDisconnectWorkItem: DispatchWorkItem?
    private var pendingReconnectWorkItem: DispatchWorkItem?

    public private(set) var reconnectAttempt: Int = 0
    public let maxReconnectAttempts: Int = 3
    public var isAutoReconnectScheduled: Bool { autoReconnect.isScheduled }
    private var hasHandledDisconnectForCurrentAttempt: Bool = false

    private lazy var autoReconnect = AutomaticReconnect(
        currentState: { [weak self] in self?.activeConnection },
        isStopping: { [weak self] in self?.isUserInitiatedDisconnect ?? false }
    )

    private(set) var state: ConnectionState = .disconnected {
        didSet {
            AppLog.i("ConnectionManager: state changed from \(oldValue.description) to \(state.description)", tag: "ConnectionManager")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.connectionManager(self, didChangeState: self.state)
            }
        }
    }

    private var hasPerformedSilentIcebreakRetry = false
    private(set) var lastConnectedDevice: DiscoveredDevice?
    private var lastSessionDiagnosticLines: [String] = []

    public var currentRxMbps: Double {
        return aapTransport?.currentRxMbps ?? 0.0
    }

    func setStateForTesting(_ newState: ConnectionState) {
        state = newState
    }

    private func setState(_ newState: ConnectionState) {
        state = newState
    }

    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var connectedDevice: DiscoveredDevice?
    private(set) var connectedPeerDeviceInfo: AapPeerDeviceInfo?
    public private(set) var statusKind: ConnectionStatusKind = .ready
    private(set) var statusDetail = L10n.statusReadyToConnect

    public var connectedPeerDisplayName: String {
        if let peer = connectedPeerDeviceInfo {
            let trimmedName = peer.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty { return trimmedName }
            let trimmedBrand = peer.phoneBrand.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBrand.isEmpty { return trimmedBrand }
        }
        if let dev = connectedDevice ?? lastConnectedDevice {
            return dev.displayName
        }
        return L10n.androidAutoDefaultName
    }

    public var connectedPeerEndpointText: String {
        guard let dev = connectedDevice ?? lastConnectedDevice else { return "" }
        return "\(dev.ip):\(dev.port)"
    }

    init() {
        discovery.delegate = self
        installAapTransport(connection: tcpHandler)
        microphoneCapture.onPCMData = { [weak self] data in
            guard ProjectionSettings.effectiveUseIpadMic else { return }
            self?.aapTransport?.sendMicrophoneAudioData(data)
        }
        locationCapture.onLocation = { [weak self] location in
            self?.aapTransport?.sendLocationUpdate(location)
        }
        NowPlayingCoordinator.shared.onRemoteCommand = { [weak self] command in
            self?.sendRemoteMediaCommand(command)
        }
        NetworkReachabilityMonitor.shared.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkReachabilityChanged(_:)),
            name: .carAutoPadNetworkReachabilityDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppLanguageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    @objc private func handleAppLanguageDidChange() {
        refreshLocalizedStatus()
    }

    func setStatusKindForTesting(_ kind: ConnectionStatusKind) {
        statusKind = kind
        statusDetail = kind.localizedText
    }

    public func refreshLocalizedStatus() {
        let localized = statusKind.localizedText
        statusDetail = localized
        let notify = { [weak self] in
            guard let self = self else { return }
            self.delegate?.connectionManager(self, didUpdateStatus: localized)
        }
        if Thread.isMainThread {
            notify()
        } else {
            DispatchQueue.main.async(execute: notify)
        }
    }

    @objc private func handleNetworkReachabilityChanged(_ notification: Notification) {
        let snapshot = NetworkReachabilityMonitor.shared.currentSnapshot
        guard let stationIp = snapshot.stationIpv4, !stationIp.isEmpty else { return }
        if state == .disconnected && ProjectionSettings.autoReconnect && !isUserInitiatedDisconnect {
            AppLog.i("Network reconnected with valid IP \(stationIp), triggering auto-discovery", tag: "ConnectionManager")
            startDiscovery(userInitiated: false)
        }
    }

    public func sendKeyEvent(keyCode: Int, isDown: Bool) {
        aapTransport?.sendKeyEvent(keyCode: keyCode, isDown: isDown)
    }

    func requestLocationPermissionIfNeeded() {
        guard ProjectionSettings.gpsSource == .ipad else { return }
        guard ProjectionSettings.supportsCellularIpad() else { return }
        locationCapture.requestPermissionIfNeeded()
    }

    func startDiscovery(userInitiated: Bool = true) {
        AppLog.i("ConnectionManager: startDiscovery called (userInitiated: \(userInitiated))", tag: "ConnectionManager")
        hasPerformedSilentIcebreakRetry = false
        if userInitiated {
            reconnectAttempt = 0
            autoReconnect.resetAttempts()
        }
        autoReconnect.cancel()
        isUserInitiatedDisconnect = false

        guard NetworkAddresses.stationIpv4() != nil else {
            AppLog.w("ConnectionManager: No Wi-Fi IPv4 address detected, aborting discovery", tag: "ConnectionManager")
            state = .disconnected
            ConnectionIssueStore.shared.raise(issue: .wifiRadioOff)
            updateStatus(.searchFailedNoWifi)
            return
        }

        ConnectionIssueStore.shared.clear(issue: .wifiRadioOff)
        ConnectionIssueStore.shared.clear(issue: .noDeviceDiscovered)
        ConnectionIssueStore.shared.clear(issue: .headunitServerStuckAfterRetries)

        let canStart: Bool
        switch state {
        case .disconnected, .error, .waitingForWirelessHelper:
            canStart = true
        default:
            canStart = false
        }

        guard canStart else {
            AppLog.w("ConnectionManager: Cannot start discovery, current state: \(state.description)", tag: "ConnectionManager")
            return
        }

        discoveredDevices.removeAll()
        state = .discovering

        let stationIp = NetworkAddresses.stationIpv4() ?? ""
        updateStatus(.scanning(stationIp: stationIp))

        Discovery.triggerLocalNetworkPermission()

        discovery.startScan(ports: [Discovery.headunitPort])
    }

    func stopDiscovery(cancelPrepared: Bool = true, resetState: Bool = true) {
        AppLog.i("ConnectionManager: stopDiscovery called (cancelPrepared=\(cancelPrepared), resetState=\(resetState))", tag: "ConnectionManager")
        autoReconnect.cancel()
        discovery.stopScan(cancelPrepared: cancelPrepared)
        if resetState && (state == .discovering || state == .waitingForWirelessHelper) {
            state = .disconnected
            updateStatus(.ready)
        }
    }

    func connect(to device: DiscoveredDevice, userInitiated: Bool = true) {
        foregroundWatchdogWorkItem?.cancel()
        foregroundWatchdogWorkItem = nil
        delayedDisconnectWorkItem?.cancel()
        delayedDisconnectWorkItem = nil
        pendingReconnectWorkItem?.cancel()
        pendingReconnectWorkItem = nil
        backgroundEnteredUptime = 0
        AppLog.i("ConnectionManager: connect(to:) called with device: \(device.displayName), userInitiated: \(userInitiated)", tag: "ConnectionManager")
        hasHandledDisconnectForCurrentAttempt = false
        if userInitiated {
            hasPerformedSilentIcebreakRetry = false
            reconnectAttempt = 0
            autoReconnect.resetAttempts()
            ConnectionIssueStore.shared.clear(issue: .headunitServerStuckAfterRetries)
            ConnectionIssueStore.shared.clear(issue: .noDeviceDiscovered)
        }
        autoReconnect.cancel()
        isUserInitiatedDisconnect = false

        let targetEndpoint = SameEndpointConnectPolicy.endpoint(host: device.ip, port: Int(device.port))
        if !userInitiated && (state == .connecting || state == .handshaking || state == .running) && targetEndpoint == lastTriedEndpoint {
            AppLog.i("ConnectionManager: In-flight connection to \(targetEndpoint) already active, ignoring duplicate connect", tag: "ConnectionManager")
            return
        }

        let inFlight = (state == .connecting || state == .handshaking || state == .running)
        guard ConnectionAdmission.admits(inFlight: inFlight, userInitiated: userInitiated) else {
            AppLog.w("ConnectionManager: Admission refused connection to \(device.displayName)", tag: "ConnectionManager")
            return
        }
        guard arbiter.claim(tier: .user, owner: .manual, what: device.displayName) != nil else {
            AppLog.w("ConnectionManager: Arbiter refused connection claim for \(device.displayName)", tag: "ConnectionManager")
            return
        }

        lastTriedEndpoint = targetEndpoint
        // 1. FIRST take the prepared socket BEFORE stopping scan / cancelling other prepared sockets!
        let prepared = discovery.takePreparedConnection(ip: device.ip, port: device.port)
        // 2. Stop scan and clean up any OTHER prepared sockets without resetting state to .disconnected
        discovery.stopScan(cancelPrepared: true)

        state = .connecting
        connectedDevice = device
        connectedPeerDeviceInfo = nil
        lastConnectedDevice = device

        installAapTransport(connection: tcpHandler)
        aapTransport?.configurePeer(host: device.ip, port: device.port)

        if let prepared = prepared {
            AppLog.category(.connectionHandshake, "[CONN] Adopting prepared discovery socket to \(device.ip):\(device.port)", tag: "ConnectionManager")
            AppLog.i("ConnectionManager: Adopting prepared discovery connection to \(device.ip):\(device.port)", tag: "ConnectionManager")
            updateStatus(.connecting(deviceName: device.displayName))
            tcpHandler.adoptConnection(prepared, host: device.ip, port: device.port)
        } else {
            AppLog.category(.connectionHandshake, "[CONN] Opening fresh TCP socket to \(device.ip):\(device.port)", tag: "ConnectionManager")
            AppLog.i("ConnectionManager: Opening fresh TCP connection to \(device.ip):\(device.port)", tag: "ConnectionManager")
            updateStatus(.connecting(deviceName: device.displayName))
            tcpHandler.connect(host: device.ip, port: device.port)
        }
    }

    func connect(to ip: String, port: UInt16 = 5277) {
        AppLog.i("ConnectionManager: connect(to:port:) called with ip: \(ip), port: \(port)", tag: "ConnectionManager")
        let device = DiscoveredDevice(ip: ip, port: port, name: nil)
        connect(to: device, userInitiated: true)
    }

    func disconnectForAppTermination() {
        AppLog.i("ConnectionManager: disconnectForAppTermination called", tag: "ConnectionManager")
        if state == .running || state == .handshaking {
            aapTransport?.sendByeByeRequestImmediately()
            activeConnection?.disconnect()
        }
    }

    func disconnect() {
        AppLog.i("ConnectionManager: disconnect called", tag: "ConnectionManager")
        isUserInitiatedDisconnect = true
        autoReconnect.cancel()
        foregroundWatchdogWorkItem?.cancel()
        foregroundWatchdogWorkItem = nil
        pendingReconnectWorkItem?.cancel()
        pendingReconnectWorkItem = nil
        backgroundEnteredUptime = 0

        NowPlayingCoordinator.shared.deactivate()
        PCMAudioPlayer.shared.stop()
        microphoneCapture.stop()
        locationCapture.stop()
        connectedDevice = nil
        connectedPeerDeviceInfo = nil
        state = .disconnected
        updateStatus(.ready)

        delayedDisconnectWorkItem?.cancel()
        delayedDisconnectWorkItem = nil

        var shouldDelayClose = false
        if let transport = aapTransport {
            lastSessionDiagnosticLines = transport.videoDiagnosticLines() + transport.teardownDiagnosticLines()
            if transport.state == .running || transport.state == .binding || transport.state == .authenticatingComplete {
                transport.send(message: .userSelectionByebyeRequest)
                shouldDelayClose = true
            }
        }

        if shouldDelayClose {
            let item = DispatchWorkItem { [weak self] in
                self?.activeConnection?.disconnect()
                self?.delayedDisconnectWorkItem = nil
            }
            delayedDisconnectWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: item)
        } else {
            activeConnection?.disconnect()
        }
    }

    public func reconnectForSettingsChange() {
        guard let device = connectedDevice ?? lastConnectedDevice else { return }
        let ip = device.ip
        let port = device.port
        AppLog.i("ConnectionManager: Reconnecting for settings change to \(ip):\(port)", tag: "ConnectionManager")
        pendingReconnectWorkItem?.cancel()
        disconnect()
        let item = DispatchWorkItem { [weak self] in
            self?.connect(to: ip, port: port)
            self?.pendingReconnectWorkItem = nil
        }
        pendingReconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
    }

    public func updateNightMode(userInterfaceStyle: UIUserInterfaceStyle? = nil, force: Bool = false) {
        let isNight = ProjectionSettings.effectiveIsNightMode(userInterfaceStyle: userInterfaceStyle)
        aapTransport?.sendNightModeEvent(isNight: isNight, force: force)
    }

    public func handleDidEnterBackground() {
        backgroundEnteredUptime = ProcessInfo.processInfo.systemUptime
        foregroundWatchdogWorkItem?.cancel()
        foregroundWatchdogWorkItem = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.connectionManagerDidEnterBackground(self)
        }
        aapTransport?.handleDidEnterBackground()
        AppLog.category(.connectionHandshake, "[CONN] App entered background (activeConnection: \(state.description))", tag: "ConnectionManager")
    }

    public func handleWillEnterForeground() {
        guard backgroundEnteredUptime > 0 else { return }
        backgroundEnteredUptime = 0

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.connectionManagerWillEnterForeground(self)
        }
        guard state == .running else { return }
        let baselineRxUptime = aapTransport?.lastInboundPacketUptime ?? 0
        aapTransport?.handleWillEnterForeground()
        AppLog.category(.connectionHandshake, "[CONN] App will enter foreground, baselineRxUptime=\(String(format: "%.3f", baselineRxUptime))", tag: "ConnectionManager")

        foregroundWatchdogWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .running else { return }
            let currentRxUptime = self.aapTransport?.lastInboundPacketUptime ?? 0
            if currentRxUptime <= baselineRxUptime {
                AppLog.category(
                    .connectionHandshake,
                    "[CONN] Foreground watchdog detected dead link (0 inbound packets in 2.5s), tearing down & reconnecting",
                    tag: "ConnectionManager",
                    level: .warn
                )
                self.aapTransport?.stop()
                (self.activeConnection ?? self.tcpHandler).disconnect()
                self.state = .disconnected
                self.hasHandledDisconnectForCurrentAttempt = false
                self.scheduleReconnectIfNeeded(reason: "Foreground resume link lost")
            } else {
                AppLog.category(
                    .connectionHandshake,
                    "[CONN] Foreground watchdog link check passed (traffic active, currentRx=\(String(format: "%.3f", currentRxUptime)))",
                    tag: "ConnectionManager"
                )
            }
        }
        foregroundWatchdogWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    func takeVideo1sNetStats() -> (fps: Int, bytes: Int, maxGapMs: Double) {
        return aapTransport?.takeVideo1sNetStats() ?? (0, 0, 0.0)
    }

    func sendTouchEvent(pointers: [(id: Int, x: Int, y: Int)], action: TouchAction, actionIndex: Int, touchTimestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        aapTransport?.sendTouchEvent(pointers: pointers, action: action, actionIndex: actionIndex, touchTimestamp: touchTimestamp)
    }

    func requestVideoRecovery() {
        guard state == .running else { return }
        aapTransport?.requestVideoRecovery()
    }

    func requestVideoFocusCycle(reason: String = "watchdog-no-first-frame") {
        guard state == .running else { return }
        aapTransport?.requestVideoFocusCycle(reason: reason)
    }

    func sendRemoteMediaCommand(_ command: RemoteMediaCommand) {
        guard state == .running else { return }
        let keyCode: Int
        switch command {
        case .play:
            keyCode = 126
        case .pause:
            keyCode = 127
        case .playPause:
            keyCode = 85
        case .next:
            keyCode = 87
        case .previous:
            keyCode = 88
        case .stop:
            keyCode = 86
        }
        aapTransport?.sendMediaKeyEvent(keyCode: keyCode)
    }

    func sendUpdateUiConfigRequest(left: Int, top: Int, right: Int, bottom: Int, uiTheme: Int32? = nil) {
        aapTransport?.sendUpdateUiConfigRequest(left: left, top: top, right: right, bottom: bottom, uiTheme: uiTheme)
    }

    func diagnosticLines() -> [String] {
        let device = connectedDevice ?? lastConnectedDevice
        let liveVideoLines = aapTransport?.videoDiagnosticLines() ?? lastSessionDiagnosticLines
        let connectionLines = [
            "State: \(state.description)",
            "Status: \(statusDetail)",
            "Auto reconnect: \(ProjectionSettings.autoReconnect ? "On" : "Off")",
            "Auto resume playback: \(ProjectionSettings.autoResumePlayback ? "On" : "Off")",
            "Local IP: \(NetworkAddresses.currentWifiIPv4Address() ?? "Unknown")",
            "Consecutive silent failures: \(consecutiveSilentFailures)",
            "Consecutive starved sessions: \(consecutiveStarvedSessions)",
            "Audio output: \(currentAudioOutputDescription())",
            "Now Playing owner: \(state == .running ? "CarAutoPad" : "Inactive")",
            "Discovered headunits: \(discoveredDevices.count)",
            "Connected device: \(device?.displayName ?? "None")",
            "Connected endpoint: \(device.map { "\($0.ip):\($0.port)" } ?? "None")",
            "",
        ]
        return connectionLines + liveVideoLines
    }

    private func installAapTransport(connection: ByteStreamConnection) {
        activeConnection = connection
        let transport = AapTransport(
            connection: connection,
            handshakeProfile: .network
        )
        transport.delegate = self
        aapTransport = transport
    }

    private func updateStatus(_ kind: ConnectionStatusKind) {
        statusKind = kind
        let status = kind.localizedText
        statusDetail = status
        AppLog.i("ConnectionManager: status = \(status)", tag: "ConnectionManager")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.connectionManager(self, didUpdateStatus: status)
        }
    }

    private func scheduleReconnectIfNeeded(reason: String) {
        guard ProjectionSettings.autoReconnect else { return }
        guard !isUserInitiatedDisconnect else { return }
        guard let targetDevice = lastConnectedDevice else { return }

        if reconnectAttempt < maxReconnectAttempts {
            reconnectAttempt += 1
            let attemptNum = reconnectAttempt
            updateStatus(.retrying(attempt: attemptNum, maxAttempts: maxReconnectAttempts))
            let session = (activeConnection ?? tcpHandler) as AnyObject
            autoReconnect.schedule(
                endedSession: session,
                delayMs: 3_000,
                ownsCheck: { [weak self] in
                    guard let self = self else { return false }
                    return !self.isUserInitiatedDisconnect
                }
            ) { [weak self] in
                guard let self = self, !self.isUserInitiatedDisconnect else { return }
                self.connect(to: targetDevice, userInitiated: false)
            }
        } else {
            autoReconnect.cancel()
            ConnectionIssueStore.shared.raise(issue: .headunitServerStuckAfterRetries)
            updateStatus(.failedAfterRetries(maxAttempts: maxReconnectAttempts))
            state = .error(L10n.errorFailedAfterRetries(maxReconnectAttempts))
        }
    }

    private func currentAudioOutputDescription() -> String {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard !outputs.isEmpty else {
            return "None"
        }
        return outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
    }
}

extension ConnectionManager: DiscoveryDelegate {
    func discoveryDidFindDevice(_ device: DiscoveredDevice) {
        guard state == .discovering else { return }
        AppLog.category(.connectionHandshake, "[CONN] Discovered headunit server \(device.displayName) (\(device.ip):\(device.port)), connecting immediately", tag: "ConnectionManager")
        AppLog.i("ConnectionManager: Discovered device \(device.displayName), connecting immediately", tag: "ConnectionManager")
        if !discoveredDevices.contains(where: { $0.ip == device.ip && $0.port == device.port }) {
            discoveredDevices.append(device)
        }
        // Stop further scanning WITHOUT cancelling the prepared connection and WITHOUT emitting "Ready to connect"
        discovery.stopScan(cancelPrepared: false)
        ConnectionIssueStore.shared.clear(issue: .noDeviceDiscovered)
        ConnectionIssueStore.shared.clear(issue: .wifiRadioOff)
        delegate?.connectionManager(self, didDiscoverDevice: device)
        connect(to: device, userInitiated: true)
    }

    func discoveryDidFinish() {
        AppLog.i("ConnectionManager: discovery finished, found \(discoveredDevices.count) devices", tag: "ConnectionManager")
        guard state == .discovering, discoveredDevices.isEmpty, connectedDevice == nil else { return }
        state = .disconnected
        if NetworkAddresses.stationIpv4() == nil {
            ConnectionIssueStore.shared.raise(issue: .wifiRadioOff)
            updateStatus(.searchFailedNoWifi)
        } else {
            ConnectionIssueStore.shared.raise(issue: .noDeviceDiscovered)
            updateStatus(.noDeviceFound)
        }
    }

    func discoveryDidFail(_ error: Error) {
        AppLog.e("ConnectionManager: discovery failed with error: \(error.localizedDescription)", tag: "ConnectionManager")
        state = .disconnected
        if NetworkAddresses.stationIpv4() == nil || (error as? DiscoveryError) == .noNetworkInterface {
            ConnectionIssueStore.shared.raise(issue: .wifiRadioOff)
            updateStatus(.searchFailedNoWifi)
        } else {
            ConnectionIssueStore.shared.raise(issue: .noDeviceDiscovered)
            updateStatus(.searchFailed(reason: error.localizedDescription))
        }
    }
}

extension ConnectionManager: AapTransportDelegate {
    func aapTransport(_ transport: AapTransport, didRequestMicrophoneCapture isOpen: Bool) {
        guard ProjectionSettings.effectiveUseIpadMic else {
            microphoneCapture.stop()
            return
        }
        if isOpen {
            microphoneCapture.start(sampleRate: 16_000, channels: 1)
        } else {
            microphoneCapture.stop()
        }
    }

    func aapTransport(_ transport: AapTransport, didRequestLocationUpdates isEnabled: Bool) {
        if isEnabled {
            locationCapture.start()
        } else {
            locationCapture.stop()
        }
    }

    func aapTransport(_ transport: AapTransport, didReceiveVideoData data: Data) {
        delegate?.connectionManager(self, didReceiveVideoData: data)
    }

    func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8) {
        delegate?.connectionManager(self, didReceiveAudioData: data, on: channel)
    }

    func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool) {
        delegate?.connectionManager(self, didReceiveAudioData: data, on: channel, isAac: isAac)
    }

    func aapTransport(_ transport: AapTransport, didReceiveAudioCodecConfig data: Data, on channel: UInt8) {
        delegate?.connectionManager(self, didReceiveAudioCodecConfig: data, on: channel)
    }

    func aapTransport(_ transport: AapTransport, didReceiveMediaMetadata metadata: AapMediaMetadata) {
        hasReceivedAaMediaMetadata = true
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = metadata.artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = metadata.album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let artwork = metadata.albumArt.flatMap { UIImage(data: $0) }

        NowPlayingCoordinator.shared.updateMetadata(
            NowPlayingMetadata(
                title: title?.isEmpty == false ? title! : "Android Auto",
                artist: artist?.isEmpty == false ? artist! : L10n.unknownArtist,
                album: album?.isEmpty == false ? album! : L10n.projectionLabel,
                durationSeconds: metadata.durationSeconds,
                artworkImage: artwork
            )
        )
    }

    func aapTransport(_ transport: AapTransport, didReceivePlaybackStatus status: AapPlaybackStatus) {
        let isPlaying = status.state == .playing
        lastPlayingState = isPlaying

        if !hasReceivedAaMediaMetadata,
           let source = status.mediaSource?.trimmingCharacters(in: .whitespacesAndNewlines),
           !source.isEmpty {
            NowPlayingCoordinator.shared.updateMetadata(
                NowPlayingMetadata(
                    title: source,
                    artist: "Android Auto",
                    album: L10n.projectionLabel,
                    durationSeconds: nil,
                    artworkImage: nil
                )
            )
        }
        NowPlayingCoordinator.shared.updatePlaybackState(
            NowPlayingPlaybackState(
                isPlaying: isPlaying,
                elapsedSeconds: status.playbackSeconds ?? 0
            )
        )
    }

    func aapTransport(_ transport: AapTransport, didReceivePeerDeviceInfo info: AapPeerDeviceInfo) {
        guard transport === aapTransport else { return }
        connectedPeerDeviceInfo = info
        let endpoint = connectedDevice ?? lastConnectedDevice
        let ip = endpoint?.ip ?? ""
        let port = endpoint?.port ?? Discovery.headunitPort
        if !ip.isEmpty {
            ConnectedPhoneStore.shared.recordConnection(
                deviceName: info.deviceName,
                hardwareModel: info.phoneBrand,
                ipAddress: ip,
                port: port
            )
        }
    }

    func aapTransport(_ transport: AapTransport, didChangeState state: AapTransportState) {
        guard transport === aapTransport else { return }
        switch state {
        case .waitingForVersion, .versionSent:
            self.state = .handshaking
            updateStatus(.waitingForHeadunitServer)

        case .tlsHandshaking, .authenticating, .authenticatingComplete, .binding:
            self.state = .handshaking
            updateStatus(.handshakingTls)

        case .running:
            NowPlayingCoordinator.shared.activate()
            if !ProjectionSettings.isAudioSinkEnabled {
                PCMAudioPlayer.shared.stop()
            }
            self.state = .running
            if let endpoint = connectedDevice ?? lastConnectedDevice {
                ConnectedPhoneStore.shared.recordConnection(
                    deviceName: connectedPeerDeviceInfo?.deviceName ?? endpoint.name,
                    hardwareModel: connectedPeerDeviceInfo?.phoneBrand,
                    ipAddress: endpoint.ip,
                    port: endpoint.port
                )
            }
            self.hasPerformedSilentIcebreakRetry = false
            reconnectAttempt = 0
            consecutiveSilentFailures = 0
            autoReconnect.resetAttempts()
            ConnectionIssueStore.shared.clearAll()
            updateStatus(.runningWireless)
            consecutiveStarvedSessions = VideoStarvationPolicy.nextStreak(
                current: consecutiveStarvedSessions,
                reachedHandshake: true,
                renderedAnyFrame: true
            )

            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let resume = playbackSnapshot.consume(now: nowMs)
            if AutoResumePlaybackPolicy.shouldResume(
                enabled: ProjectionSettings.autoResumePlayback,
                wasPlayingBeforeDisconnect: resume.wasPlaying,
                elapsedSinceDisconnectMs: resume.elapsedMs
            ) {
                AppLog.i("ConnectionManager: AutoResumePlaybackPolicy satisfied, resuming playback", tag: "ConnectionManager")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.sendRemoteMediaCommand(.play)
                }
            }

        case .error(let msg):
            NowPlayingCoordinator.shared.deactivate()
            PCMAudioPlayer.shared.stop()
            microphoneCapture.stop()
            locationCapture.stop()
            self.state = .error(msg)
            if msg == "Handshake timeout - no response from Headunit Server" {
                updateStatus(.handshakeVersionTimeout)
            } else if msg == "TLS handshake timeout" {
                updateStatus(.tlsHandshakeTimeout)
            } else {
                updateStatus(.customError(msg))
            }

            consecutiveSilentFailures = UnresponsivePeerPolicy.countAfterSilentFailure(
                previousCount: consecutiveSilentFailures,
                previousEndpoint: lastTriedEndpoint,
                endpoint: lastTriedEndpoint
            )

            guard !hasHandledDisconnectForCurrentAttempt else { return }
            hasHandledDisconnectForCurrentAttempt = true
            scheduleReconnectIfNeeded(reason: "Android Auto error")

        default:
            break
        }
    }

    func aapTransportDidDisconnect(_ transport: AapTransport) {
        guard transport === aapTransport else { return }
        lastSessionDiagnosticLines = transport.videoDiagnosticLines() + transport.teardownDiagnosticLines()
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        playbackSnapshot.onDisconnected(
            lastPlaying: lastPlayingState,
            now: nowMs,
            deliberate: isUserInitiatedDisconnect
        )

        aapTransport = nil
        NowPlayingCoordinator.shared.deactivate()
        PCMAudioPlayer.shared.stop()
        microphoneCapture.stop()
        locationCapture.stop()
        connectedDevice = nil
        connectedPeerDeviceInfo = nil
        state = .disconnected
        updateStatus(.disconnectedFromSession)

        consecutiveStarvedSessions = VideoStarvationPolicy.nextStreak(
            current: consecutiveStarvedSessions,
            reachedHandshake: transport.didReachRunning,
            renderedAnyFrame: false
        )
        if VideoStarvationPolicy.shouldAdvise(consecutiveStarvedSessions: consecutiveStarvedSessions) {
            AppLog.w("ConnectionManager: VideoStarvationPolicy advises lowering resolution/fps", tag: "ConnectionManager")
        }

        guard !hasHandledDisconnectForCurrentAttempt else { return }
        hasHandledDisconnectForCurrentAttempt = true
        scheduleReconnectIfNeeded(reason: "Android Auto disconnected")
    }

    func aapTransportDidRequestExit(_ transport: AapTransport) {
        guard transport === aapTransport else { return }
        AppLog.i("ConnectionManager: AapTransport requested exit (native video focus)", tag: "ConnectionManager")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isUserInitiatedDisconnect = true
            self.autoReconnect.cancel()
            self.disconnect()
        }
    }

    func aapTransportDidDetectSilentPeerOnInitialHandshake(_ transport: AapTransport) {
        guard transport === aapTransport, let device = connectedDevice else { return }
        AppLog.w("No VERSION_RESPONSE after 3.0s on \(device.ip):\(device.port); disconnecting to trigger auto-reconnect", tag: "ConnectionManager")
        (activeConnection ?? tcpHandler).disconnect()
    }
}
