import Foundation
import Network
import CoreLocation

protocol AapTransportDelegate: AnyObject {
    func aapTransport(_ transport: AapTransport, didReceiveVideoData data: Data)
    func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8)
    func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool)
    func aapTransport(_ transport: AapTransport, didReceiveAudioCodecConfig data: Data, on channel: UInt8)
    func aapTransport(_ transport: AapTransport, didReceiveMediaMetadata metadata: AapMediaMetadata)
    func aapTransport(_ transport: AapTransport, didReceivePlaybackStatus status: AapPlaybackStatus)
    func aapTransport(_ transport: AapTransport, didRequestMicrophoneCapture isOpen: Bool)
    func aapTransport(_ transport: AapTransport, didRequestLocationUpdates isEnabled: Bool)
    func aapTransport(_ transport: AapTransport, didChangeState state: AapTransportState)
    func aapTransportDidDisconnect(_ transport: AapTransport)
    func aapTransportDidRequestExit(_ transport: AapTransport)
    func aapTransportDidDetectSilentPeerOnInitialHandshake(_ transport: AapTransport)
}

extension AapTransportDelegate {
    func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool) {
        aapTransport(transport, didReceiveAudioData: data, on: channel)
    }
    func aapTransport(_ transport: AapTransport, didReceiveAudioCodecConfig data: Data, on channel: UInt8) {}
    func aapTransportDidRequestExit(_ transport: AapTransport) {}
    func aapTransportDidDetectSilentPeerOnInitialHandshake(_ transport: AapTransport) {}
}

struct AapMediaMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let durationSeconds: UInt64?
    let albumArt: Data?
}

struct AapPlaybackStatus {
    enum State: UInt64 {
        case stopped = 1
        case playing = 2
        case paused = 3
    }

    let state: State?
    let mediaSource: String?
    let playbackSeconds: UInt64?
}

enum AapTransportError: Error {
    case encryptionFailed
    case transportGone
}

enum AapTransportState: Equatable {
    case idle
    case waitingForVersion
    case versionSent
    case tlsHandshaking
    case authenticating
    case authenticatingComplete
    case binding
    case running
    case error(String)
}

class AapTransport {
    weak var delegate: AapTransportDelegate?

    private let connection: ByteStreamConnection
    private let tlsHandler = OpenSslTlsHandler()
    private let handshakeQueue = DispatchQueue(label: "com.carautopad.aap.handshake", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.carautopad.aap.processing", qos: .userInteractive)
    private let processingQueueKey = DispatchSpecificKey<Void>()
    private var pendingMediaAcks: [UInt8: UInt32] = [:]
    private(set) var state: AapTransportState = .idle
    private var handshakeTimer: DispatchWorkItem?
    private let versionHandshakeTimeout: TimeInterval
    private let tlsHandshakeTimeout: TimeInterval = 15.0
    var initialVersionRequestDelay: TimeInterval = 0.5
    var versionRetryInterval: TimeInterval = 2.0
    private let maxVersionRequestAttempts: Int
    private var versionRequestAttempts = 0
    private var versionRetryWorkItem: DispatchWorkItem?
    private var delayedVersionStartWorkItem: DispatchWorkItem?
    private var peerHost: String?
    private var peerPort: UInt16 = 5277
    private var hasTriggeredLauncherPoke = false
    private let enableLauncherPokeFallback = false
    private var tlsIdentityReady = false
    private let reassembler = AapMessageReassembler()
    private let fragmentAudit = FragmentedMessageAudit()
    private let linkGapMonitor = LinkGapMonitor()
    private let videoGapMonitor = LinkGapMonitor(
        subject: LinkGapMonitor.subjectVideo,
        minGaps: LinkGapMonitor.minGapsMedia,
        maxDeadPercent: LinkGapMonitor.maxDeadPercentMedia
    )
    private let audioGapMonitor = LinkGapMonitor(
        subject: LinkGapMonitor.subjectAudio,
        minGaps: LinkGapMonitor.minGapsMedia,
        maxDeadPercent: LinkGapMonitor.maxDeadPercentMedia
    )
    private let uplinkStallMonitor = UplinkStallMonitor()
    private let inboundRateMonitor = InboundRateMonitor()
    private var lastInboundMessageMs: Int64 = 0
    private var mediaSessionIds: [UInt8: UInt64] = [:]
    private var sinkCodecs: [UInt8: AudioSinkCodec] = [:]
    private var audioAssemblyBuffers: [UInt8: Data] = [:]
    private var videoAssemblyBuffer = Data()
    private var videoAssemblyMessageType: UInt16 = 0
    private var videoFirstFragmentAtMs: UInt64 = 0
    private var lastVideoRecoveryRequestAtMs: UInt64 = 0
    private let focusCycleLever = FocusCycleLever()
    private var focusCyclesUsedThisSession = 0
    private var lastFocusCycleAtMs: Int64 = 0
    private var lastWireCorruptionAtMs: Int64 = 0
    private var unrepairedSinceAtMs: Int64 = 0
    private let videoAssemblyTimeoutMs: UInt64 = 1200
    private let minVideoRecoveryIntervalMs: UInt64 = 1500
    private let maxVideoAssemblyBytes = 6 * 1024 * 1024
    private var consecutiveTlsDecryptFailures = 0
    private var consecutiveTlsEncryptFailures = 0
    private let maxConsecutiveTlsFailures = 6
    private var startedSensors: Set<UInt64> = []
    private var lastSentNightMode: Bool? = nil
    private var isVideoChannelStarted: Bool = false
    private struct AapTraceEntry {
        let timestampMs: UInt64
        let direction: String
        let channel: UInt8
        let flags: UInt8
        let type: UInt16
        let payloadSize: Int
    }
    private var lastAapTrace: [AapTraceEntry] = []
    private let maxAapTraceEntries = 40
    private let aapTraceLock = NSLock()
    private var lastVideoPacketRxAtMs: UInt64 = 0
    private let videoDiagnosticsLock = NSLock()
    private var videoPacketCount = 0
    private var completedVideoFrameCount = 0
    private var lastCompletedVideoFrameBytes = 0
    private var videoDataMessageCount = 0
    private var videoCodecConfigMessageCount = 0
    private var lastVideoCodecConfigPrefix = "None"
    private var videoRecoveryRequestCount = 0
    private var lastVideoRecoveryReason = "None"
    private let gracefulDisconnectLock = NSLock()
    private var gracefulDisconnectTimeout: DispatchWorkItem?
    private var gracefulDisconnectCompletion: (() -> Void)?
    private var gracefulDisconnectDiagnostic = "Not requested"
    private var gracefulDisconnectWriteFlushed = false
    private let byebyeWriteTimeout: TimeInterval = 2.5
    private let byebyeResponseTimeout: TimeInterval = 1.5
    private var peerDisconnectDiagnostic = "None"

    public private(set) var lastInboundPacketUptime: TimeInterval = 0
    private var lastPingSentUptime: TimeInterval = 0
    private var tlsHandshakeStartUptime: TimeInterval = 0

    private let touchQueueLock = NSLock()
    private var pendingTouchEvents: [(message: AapMessage, touchTimestamp: TimeInterval, enqueueUptime: TimeInterval, action: TouchAction, point: (x: Int, y: Int))] = []
    private var lastMoveTouchLogUptime: TimeInterval = 0

    private let videoNetStatsLock = NSLock()
    private var netRxVideoFrames1s: Int = 0
    private var netRxVideoBytes1s: Int = 0
    private var maxNetInterFrameGapMs1s: Double = 0
    private var lastVideoFrameRxUptime: TimeInterval = 0

    public func takeVideo1sNetStats() -> (fps: Int, bytes: Int, maxGapMs: Double) {
        videoNetStatsLock.lock()
        defer { videoNetStatsLock.unlock() }
        let stats = (fps: netRxVideoFrames1s, bytes: netRxVideoBytes1s, maxGapMs: maxNetInterFrameGapMs1s)
        netRxVideoFrames1s = 0
        netRxVideoBytes1s = 0
        maxNetInterFrameGapMs1s = 0
        return stats
    }

    private var receiveBuffer = Data()
    private var encryptedReceiveBuffer = Data()
    private let bufferLock = NSLock()

    enum HandshakeProfile {
        case network

        var versionTimeout: TimeInterval {
            switch self {
            case .network: return 5.0
            }
        }

        var versionAttempts: Int {
            switch self {
            case .network: return 3
            }
        }
    }

    init(connection: ByteStreamConnection, handshakeProfile: HandshakeProfile = .network) {
        self.connection = connection
        self.versionHandshakeTimeout = handshakeProfile.versionTimeout
        self.maxVersionRequestAttempts = handshakeProfile.versionAttempts
        self.connection.delegate = self
        self.processingQueue.setSpecific(key: processingQueueKey, value: ())
        setupTls()
        setupReassembler()
    }

    private func setupReassembler() {
        reassembler.onDroppedVideoPayload = { [weak self] in
            AppLog.w("Reassembler dropped video fragment, requesting video recovery", tag: "AapTransport")
            self?.requestVideoRecoveryIfNeeded(reason: "reassembler-dropped-video", ignoreRecentVideoGuard: false, isWireCorruption: true)
        }
        reassembler.onDroppedMediaData = { channel in
            AppLog.w("Reassembler dropped media data on channel \(channel)", tag: "AapTransport")
        }
        reassembler.onDrop = { reason in
            AppLog.w("Reassembler dropped: \(reason)", tag: "AapTransport")
        }
    }

    func configurePeer(host: String, port: UInt16) {
        peerHost = host
        peerPort = port
    }

    private func setupTls() {
        if tlsHandler.setup() {
            AppLog.i("OpenSSL TLS handler initialized", tag: "AapTransport")

            let bundles = [Bundle.main, Bundle(for: AapTransport.self)]
            let candidateSubdirs: [String?] = [
                "CarAutoPad/Resources/Raw",
                "Resources/Raw",
                "Raw",
                nil
            ]

            var certPath: String?
            var keyPath: String?

            for b in bundles {
                for dir in candidateSubdirs {
                    if certPath == nil, let p = b.path(forResource: "cert", ofType: nil, inDirectory: dir), FileManager.default.fileExists(atPath: p) {
                        certPath = p
                    }
                    if keyPath == nil, let p = b.path(forResource: "privkey", ofType: nil, inDirectory: dir), FileManager.default.fileExists(atPath: p) {
                        keyPath = p
                    }
                }
            }

            guard let certPath, let keyPath else {
                AppLog.i("Certificate resources not found in app bundle", tag: "AapTransport")
                return
            }

            AppLog.i("Using cert path: \(certPath)", tag: "AapTransport")
            AppLog.i("Using key path: \(keyPath)", tag: "AapTransport")

            if tlsHandler.loadCertificate(certPath: certPath, keyPath: keyPath) {
                tlsIdentityReady = tlsHandler.hasClientIdentity()
                AppLog.i("Certificate loaded successfully, ready=\(tlsIdentityReady)", tag: "AapTransport")
            } else {
                tlsIdentityReady = false
                AppLog.w("Failed to load certificate", tag: "AapTransport")
            }
        }
    }

    public func stop() {
        handshakeTimer?.cancel()
        handshakeTimer = nil
        versionRetryWorkItem?.cancel()
        versionRetryWorkItem = nil
        delayedVersionStartWorkItem?.cancel()
        delayedVersionStartWorkItem = nil
        cancelGracefulDisconnect()
        setState(.idle)
    }

    func startHandshake() {
        AppLog.i("Starting handshake", tag: "AapTransport")
        bufferLock.lock()
        receiveBuffer.removeAll()
        encryptedReceiveBuffer.removeAll()
        bufferLock.unlock()
        reassembler.reset()
        fragmentAudit.reset()
        linkGapMonitor.reset()
        videoGapMonitor.reset()
        audioGapMonitor.reset()
        uplinkStallMonitor.reset()
        inboundRateMonitor.reset()
        lastInboundMessageMs = Int64(Date().timeIntervalSince1970 * 1000)
        tlsHandler.releaseSessionOnly()
        versionRetryWorkItem?.cancel()
        versionRetryWorkItem = nil
        delayedVersionStartWorkItem?.cancel()
        delayedVersionStartWorkItem = nil
        versionRequestAttempts = 0
        hasTriggeredLauncherPoke = false
        videoAssemblyBuffer.removeAll(keepingCapacity: true)
        videoAssemblyMessageType = 0
        videoFirstFragmentAtMs = 0
        lastVideoPacketRxAtMs = 0
        lastVideoRecoveryRequestAtMs = 0
        mediaSessionIds = [
            Channel.ID_VID: 0,
            Channel.ID_AUD: 0,
            Channel.ID_AU1: 0,
            Channel.ID_AU2: 0,
            Channel.ID_MIC: 0
        ]
        sinkCodecs.removeAll()
        audioAssemblyBuffers.removeAll()
        pendingMediaAcks.removeAll()
        focusCyclesUsedThisSession = 0
        lastFocusCycleAtMs = 0
        lastWireCorruptionAtMs = 0
        unrepairedSinceAtMs = 0
        focusCycleLever.release()
        videoDiagnosticsLock.lock()
        videoPacketCount = 0
        completedVideoFrameCount = 0
        lastCompletedVideoFrameBytes = 0
        videoDataMessageCount = 0
        videoCodecConfigMessageCount = 0
        lastVideoCodecConfigPrefix = "None"
        videoRecoveryRequestCount = 0
        lastVideoRecoveryReason = "None"
        videoDiagnosticsLock.unlock()
        gracefulDisconnectLock.lock()
        gracefulDisconnectDiagnostic = "Not requested"
        peerDisconnectDiagnostic = "None"
        gracefulDisconnectLock.unlock()
        startedSensors.removeAll()
        lastSentNightMode = nil
        isVideoChannelStarted = false
        setState(.waitingForVersion)

        let delayedStart = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.sendVersionRequestWithRetry()
        }
        delayedVersionStartWorkItem = delayedStart
        handshakeQueue.asyncAfter(deadline: .now() + initialVersionRequestDelay, execute: delayedStart)

        startHandshakeTimeout(for: .waitingForVersion)
    }

    private func startHandshakeTimeout(for handshakeState: AapTransportState) {
        handshakeTimer?.cancel()

        let timeout: TimeInterval
        switch handshakeState {
        case .waitingForVersion:
            timeout = versionHandshakeTimeout
        case .tlsHandshaking:
            timeout = tlsHandshakeTimeout
        default:
            return
        }

        let timer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if case .waitingForVersion = handshakeState, case .waitingForVersion = self.state {
                AppLog.w("Handshake timeout - no version response received", tag: "AapTransport")
                self.setState(.error("Handshake timeout - no response from Headunit Server"))
                self.delegate?.aapTransportDidDisconnect(self)
            }
            if case .tlsHandshaking = handshakeState, case .tlsHandshaking = self.state {
                AppLog.w("TLS handshake timeout", tag: "AapTransport")
                self.setState(.error("TLS handshake timeout"))
                self.delegate?.aapTransportDidDisconnect(self)
            }
        }
        handshakeTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timer)
    }

    func setState(_ newState: AapTransportState) {
        AppLog.i("State changed from \(state) to \(newState)", tag: "AapTransport")
        state = newState
        if newState == .running {
            didReachRunning = true
            sendNightModeEvent(isNight: ProjectionSettings.effectiveIsNightMode())
        }

        if newState != .waitingForVersion && newState != .tlsHandshaking {
            handshakeTimer?.cancel()
            handshakeTimer = nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.aapTransport(self, didChangeState: newState)
        }
    }

    private func sendVersionRequest() {
        let versionRequest = Data([0x00, 0x02, 0x00, 0x00])
        let message = AapMessage(
            channel: Channel.ID_CTR,
            flags: 0x03,
            type: AapMessageType.VERSION_REQUEST.rawValue,
            payload: versionRequest
        )

        let encoded = message.toData()
        let hex = encoded.map { String(format: "%02x", $0) }.joined(separator: " ")
        AppLog.i("Sending version request bytes=\(hex)", tag: "AapTransport")
        sendRaw(encoded)
    }

    private func sendVersionRequestWithRetry() {
        guard state == .waitingForVersion else {
            return
        }

        versionRequestAttempts += 1

        AppLog.i("VERSION_REQUEST attempt \(versionRequestAttempts)/\(maxVersionRequestAttempts)", tag: "AapTransport")
        sendVersionRequest()

        guard versionRequestAttempts < maxVersionRequestAttempts else {
            return
        }

        let retryWork = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.sendVersionRequestWithRetry()
        }
        versionRetryWorkItem?.cancel()
        versionRetryWorkItem = retryWork
        handshakeQueue.asyncAfter(deadline: .now() + versionRetryInterval, execute: retryWork)
    }

    private func triggerLauncherPokeIfNeeded() {
        guard enableLauncherPokeFallback else {
            return
        }
        guard !hasTriggeredLauncherPoke else {
            return
        }
        guard let host = peerHost, peerPort == 5277 else {
            return
        }

        hasTriggeredLauncherPoke = true
        AppLog.i("No version response yet; poking Wifi Launcher at \(host):5289", tag: "AapTransport")

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: 5289)!)
        let params = NWParameters.tcp
        params.prohibitExpensivePaths = true

        let pokeConnection = NWConnection(to: endpoint, using: params)
        let pokeQueue = DispatchQueue(label: "com.carautopad.aap.launcher-poke", qos: .utility)
        let timeoutWorkItem = DispatchWorkItem {
            pokeConnection.cancel()
            AppLog.w("Wifi Launcher poke timeout", tag: "AapTransport")
        }

        pokeConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                AppLog.i("Wifi Launcher poke connected", tag: "AapTransport")
                pokeQueue.asyncAfter(deadline: .now() + 0.25) {
                    pokeConnection.cancel()
                }
            case .failed(let error):
                AppLog.w("Wifi Launcher poke failed: \(error)", tag: "AapTransport")
                timeoutWorkItem.cancel()
            case .cancelled:
                timeoutWorkItem.cancel()
            default:
                break
            }
        }

        pokeConnection.start(queue: pokeQueue)
        pokeQueue.asyncAfter(deadline: .now() + 1.0, execute: timeoutWorkItem)
    }

    private func sendStatusOk() {
        let statusData = Data([0x08, 0x00])
        let message = AapMessage(
            channel: Channel.ID_CTR,
            flags: 0x03,
            type: AapMessageType.AUTH_COMPLETE.rawValue,
            payload: statusData
        )

        AppLog.i("Sending status OK (plaintext)", tag: "AapTransport")
        sendRaw(message.toData())
    }

    func send(message: AapMessage, completion: ((Error?) -> Void)? = nil) {
        recordAapTrace(direction: "TX", channel: message.channelUInt8, flags: message.flags, type: message.typeUInt16, payloadSize: message.payloadSize)

        if state == .authenticating || state == .authenticatingComplete || state == .binding || state == .running {
            processingQueue.async { [weak self] in
                guard let self else {
                    completion?(AapTransportError.transportGone)
                    return
                }
                self.sendEncryptedMessage(message, completion: completion)
            }
        } else {
            let data = message.toData()
            connection.send(data, completion: completion)
        }
    }

    private func sendOnProcessingQueue(message: AapMessage, completion: ((Error?) -> Void)? = nil) {
        recordAapTrace(direction: "TX", channel: message.channelUInt8, flags: message.flags, type: message.typeUInt16, payloadSize: message.payloadSize)

        if state == .authenticating || state == .authenticatingComplete || state == .binding || state == .running {
            sendEncryptedMessage(message, completion: completion)
        } else {
            let data = message.toData()
            connection.send(data, completion: completion)
        }
    }

    private func sendEncryptedMessage(_ message: AapMessage, completion: ((Error?) -> Void)? = nil) {
        var plain = Data()
        plain.append(UInt8((message.type >> 8) & 0xFF))
        plain.append(UInt8(message.type & 0xFF))
        plain.append(message.payload)

        guard let encryptedPayload = tlsHandler.encrypt(data: plain) else {
            AppLog.w("Failed to encrypt message type=\(message.type)", tag: "AapTransport")
            registerTlsEncryptFailure(context: "message-type-\(message.type)")
            completion?(AapTransportError.encryptionFailed)
            return
        }
        consecutiveTlsEncryptFailures = 0

        let flags = encryptedFlags(for: message)
        var packet = Data()
        packet.append(message.channelUInt8)
        packet.append(flags)

        let encLen = UInt16(encryptedPayload.count)
        packet.append(UInt8((encLen >> 8) & 0xFF))
        packet.append(UInt8(encLen & 0xFF))
        packet.append(encryptedPayload)

        uplinkStallMonitor.onWriteStarted()
        connection.send(packet) { [weak self] error in
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            if let stallReport = self?.uplinkStallMonitor.onWriteCompleted(nowMs: nowMs) {
                AppLog.w("UplinkStall: \(stallReport)", tag: "AapTransport")
            }
            completion?(error)
        }
    }

    private func encryptedFlags(for message: AapMessage) -> UInt8 {
        if message.channel != Int(Channel.ID_CTR) && isControlMessageType(message.typeUInt16) {
            return 0x0f
        }
        return 0x0b
    }

    private func isControlMessageType(_ type: UInt16) -> Bool {
        return type >= 1 && type <= 26
    }

    func sendRaw(_ data: Data) {
        connection.send(data)
    }

    func requestVideoRecovery() {
        requestVideoRecoveryIfNeeded(reason: "external-watchdog", ignoreRecentVideoGuard: true)
    }

    private(set) var didReachRunning = false

    func teardownDiagnosticLines() -> [String] {
        gracefulDisconnectLock.lock()
        let graceful = gracefulDisconnectDiagnostic
        let flushed = gracefulDisconnectWriteFlushed
        let peer = peerDisconnectDiagnostic
        gracefulDisconnectLock.unlock()
        return [
            "Previous session graceful disconnect: \(graceful)",
            "Previous session byebye reached the wire: \(flushed ? "Yes" : "No")",
            "Previous session peer disconnect: \(peer)",
        ]
    }

    func videoDiagnosticLines() -> [String] {
        videoDiagnosticsLock.lock()
        let packets = videoPacketCount
        let frames = completedVideoFrameCount
        let lastFrameBytes = lastCompletedVideoFrameBytes
        let dataMessages = videoDataMessageCount
        let codecConfigMessages = videoCodecConfigMessageCount
        let codecConfigPrefix = lastVideoCodecConfigPrefix
        let recoveryRequests = videoRecoveryRequestCount
        let recoveryReason = lastVideoRecoveryReason
        videoDiagnosticsLock.unlock()
        aapTraceLock.lock()
        let videoTrace = lastAapTrace
            .filter { $0.channel == Channel.ID_VID }
            .suffix(12)
            .map { entry in
                "AAP video trace: \(entry.direction) flags=0x\(String(format: "%02x", entry.flags)) type=\(entry.type) bytes=\(entry.payloadSize)"
            }
        let allTrace = lastAapTrace
            .suffix(20)
            .map { entry in
                "AAP trace: \(entry.direction) ch=\(Channel.name(for: entry.channel))(\(entry.channel)) flags=0x\(String(format: "%02x", entry.flags)) type=\(entry.type) bytes=\(entry.payloadSize)"
            }
        aapTraceLock.unlock()
        gracefulDisconnectLock.lock()
        let gracefulDisconnect = gracefulDisconnectDiagnostic
        let byebyeFlushed = gracefulDisconnectWriteFlushed
        let peerDisconnect = peerDisconnectDiagnostic
        gracefulDisconnectLock.unlock()
        var lines = [
            "AAP video packets: \(packets)",
            "AAP completed video frames: \(frames)",
            "AAP last completed frame bytes: \(lastFrameBytes)",
            "AAP video data/config messages: \(dataMessages)/\(codecConfigMessages)",
            "AAP last codec config prefix: \(codecConfigPrefix)",
            "AAP video recovery requests: \(recoveryRequests)",
            "AAP last video recovery reason: \(recoveryReason)",
            "AAP graceful disconnect: \(gracefulDisconnect)",
            "AAP byebye reached the wire: \(byebyeFlushed ? "Yes" : "No")",
            "AAP peer disconnect: \(peerDisconnect)",
        ]
        if videoTrace.isEmpty {
            lines.append("AAP video trace: None")
        } else {
            lines.append(contentsOf: videoTrace)
        }
        if allTrace.isEmpty {
            lines.append("AAP recent trace: None")
        } else {
            lines.append(contentsOf: allTrace)
        }
        return lines
    }

    func requestVideoRecoveryForNewDisplay() {
        requestVideoRecoveryIfNeeded(reason: "new-display", ignoreRecentVideoGuard: true)
    }

    public enum DisconnectReason: String {
        case userSelection
        case orientationChange
        case error
    }

    public var currentRxMbps: Double {
        return inboundRateMonitor.currentRxMbps()
    }

    func sendByeByeRequestImmediately() {
        AppLog.i("Sending immediate ByeByeRequest", tag: "AapTransport")
        send(message: .userSelectionByebyeRequest)
    }

    func requestGracefulDisconnect(reason: DisconnectReason = .userSelection, completion: @escaping () -> Void) {
        guard state == .running else {
            DispatchQueue.main.async(execute: completion)
            return
        }

        let timeout = DispatchWorkItem { [weak self] in
            self?.finishGracefulDisconnect(reason: "timeout")
        }
        gracefulDisconnectLock.lock()
        guard gracefulDisconnectCompletion == nil else {
            gracefulDisconnectLock.unlock()
            return
        }
        gracefulDisconnectCompletion = completion
        gracefulDisconnectTimeout = timeout
        gracefulDisconnectDiagnostic = "Request sent"
        gracefulDisconnectLock.unlock()

        send(message: .userSelectionByebyeRequest) { [weak self] error in
            guard let self else { return }
            AppLog.w("Byebye write finished, error=\(error.map(String.init(describing:)) ?? "none")", tag: "AapTransport")
            self.gracefulDisconnectLock.lock()
            self.gracefulDisconnectWriteFlushed = error == nil
            self.gracefulDisconnectLock.unlock()
            DispatchQueue.main.asyncAfter(
                deadline: .now() + self.byebyeResponseTimeout,
                execute: timeout
            )
        }
        AppLog.i("Sent byebye request for user selection", tag: "AapTransport")
        DispatchQueue.main.asyncAfter(deadline: .now() + byebyeWriteTimeout) { [weak self] in
            self?.finishGracefulDisconnect(reason: "write-timeout")
        }
    }

    private func flushPendingTouchEventsOnProcessingQueue() {
        touchQueueLock.lock()
        guard !pendingTouchEvents.isEmpty else {
            touchQueueLock.unlock()
            return
        }
        let events = pendingTouchEvents
        pendingTouchEvents.removeAll(keepingCapacity: true)
        touchQueueLock.unlock()

        let now = ProcessInfo.processInfo.systemUptime
        for item in events {
            let uiToDispatchMs = max(0, (item.enqueueUptime - item.touchTimestamp) * 1000.0)
            let queueWaitMs = max(0, (now - item.enqueueUptime) * 1000.0)
            let encStart = ProcessInfo.processInfo.systemUptime
            sendEncryptedMessage(item.message)
            let encEnd = ProcessInfo.processInfo.systemUptime
            let encMs = max(0, (encEnd - encStart) * 1000.0)
            let totalTxMs = max(0, (encEnd - item.touchTimestamp) * 1000.0)

            var shouldLog = false
            if item.action == .DOWN || item.action == .UP || item.action == .POINTER_DOWN || item.action == .POINTER_UP {
                shouldLog = true
            } else if item.action == .MOVE {
                if now - lastMoveTouchLogUptime >= 0.200 {
                    lastMoveTouchLogUptime = now
                    shouldLog = true
                }
            }

            if shouldLog {
                AppLog.category(
                    .touchLatency,
                    "[TOUCH] action=\(item.action) pt=(\(item.point.x),\(item.point.y)) | uiToDispatch=\(String(format: "%.2f", uiToDispatchMs))ms | queueWait=\(String(format: "%.2f", queueWaitMs))ms | tlsEncryptSend=\(String(format: "%.2f", encMs))ms | totalTx=\(String(format: "%.2f", totalTxMs))ms",
                    tag: "AapTransport"
                )
            }
        }
    }

    func sendTouchEvent(x: Int, y: Int, action: TouchAction, pointerId: Int = 0) {
        sendTouchEvent(
            pointers: [(id: pointerId, x: x, y: y)],
            action: action,
            actionIndex: 0,
            touchTimestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    func sendTouchEvent(pointers: [(id: Int, x: Int, y: Int)], action: TouchAction, actionIndex: Int, touchTimestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !pointers.isEmpty else { return }

        let protoAction: ProtoTouchEvent.PointerAction
        switch action {
        case .DOWN: protoAction = .touchActionDown
        case .UP: protoAction = .touchActionUp
        case .MOVE: protoAction = .touchActionMove
        case .CANCEL: protoAction = .touchActionCancel
        case .POINTER_DOWN: protoAction = .touchActionPointerDown
        case .POINTER_UP: protoAction = .touchActionPointerUp
        }

        let message = AapTouchEventMessage.make(
            timestampNs: UInt64(DispatchTime.now().uptimeNanoseconds / 1000),
            action: protoAction,
            actionIndex: actionIndex,
            pointers: pointers
        )

        let firstPt = (x: pointers[0].x, y: pointers[0].y)
        let enqueueUptime = ProcessInfo.processInfo.systemUptime

        touchQueueLock.lock()
        pendingTouchEvents.append((message: message, touchTimestamp: touchTimestamp, enqueueUptime: enqueueUptime, action: action, point: firstPt))
        touchQueueLock.unlock()

        processingQueue.async { [weak self] in
            self?.flushPendingTouchEventsOnProcessingQueue()
        }
    }

    func sendMediaKeyEvent(keyCode: Int) {
        guard state == .running else { return }
        sendKeyEvent(keyCode: keyCode, isDown: true)
        sendKeyEvent(keyCode: keyCode, isDown: false)
    }

    func sendKeyEvent(keyCode: Int, isDown: Bool) {
        guard state == .running else { return }
        let key = ProtoWire.fieldVarint(1, value: UInt64(max(keyCode, 0)))
            + ProtoWire.fieldVarint(2, value: isDown ? 1 : 0)
            + ProtoWire.fieldVarint(3, value: 0)
            + ProtoWire.fieldVarint(4, value: 0)

        let keyEvent = ProtoWire.fieldBytes(1, value: key)
        let payload = ProtoWire.fieldVarint(1, value: DispatchTime.now().uptimeNanoseconds)
            + ProtoWire.fieldBytes(4, value: keyEvent)

        let message = AapMessage(
            channel: Channel.ID_INP,
            flags: 0x00,
            type: 0x8001,
            payload: payload
        )

        AppLog.i("Send keyCode=\(keyCode) isDown=\(isDown)", tag: "AapTransport")
        send(message: message)
    }

    func sendMicrophoneAudioData(_ pcmData: Data) {
        guard !pcmData.isEmpty else { return }
        guard state == .running || state == .binding || state == .authenticatingComplete else { return }

        let timestampUs = Int64(Date().timeIntervalSince1970 * 1_000_000)
        var streamPayload = Data(count: 10 + pcmData.count)
        streamPayload.withUnsafeMutableBytes { raw in
            let ptr = raw.baseAddress!
            ptr.advanced(by: 0).assumingMemoryBound(to: UInt8.self).pointee = 0
            ptr.advanced(by: 1).assumingMemoryBound(to: UInt8.self).pointee = 0

            var remaining = timestampUs
            for i in stride(from: 7, through: 0, by: -1) {
                ptr.advanced(by: 2 + i).assumingMemoryBound(to: UInt8.self).pointee = UInt8(remaining & 0xFF)
                remaining = remaining >> 8
            }

            pcmData.withUnsafeBytes { pcmRaw in
                memcpy(ptr.advanced(by: 10), pcmRaw.baseAddress!, pcmData.count)
            }
        }

        sendEncryptedRawStream(channel: Channel.ID_MIC, flags: MicUplinkFrame.flags, payload: streamPayload)
    }

    func sendLocationUpdate(_ location: CLLocation) {
        guard state == .running else { return }
        guard ProjectionSettings.gpsSource == .ipad else { return }
        guard startedSensors.contains(1) else { return }

        let timestampMs = UInt64(max(0, Int64(location.timestamp.timeIntervalSince1970 * 1000)))
        let latitude = Int32(clamping: Int64((location.coordinate.latitude * 1e7).rounded()))
        let longitude = Int32(clamping: Int64((location.coordinate.longitude * 1e7).rounded()))
        let altitude = Int32(clamping: Int64((location.altitude * 1e2).rounded()))
        let speed = location.speed >= 0 ? Int32(clamping: Int64((location.speed * 1e3).rounded())) : nil
        let bearing = location.course >= 0 ? Int32(clamping: Int64((location.course * 1e6).rounded())) : nil
        let accuracy = UInt32(clamping: max(0, Int64((location.horizontalAccuracy * 1e3).rounded())))

        let locData = SensorBatch.LocationData(
            timestamp: timestampMs,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            altitude: altitude,
            speed: speed,
            bearing: bearing
        )
        let sensorBatch = SensorBatch(locationData: [locData])
        var writer = ProtoWriter()
        sensorBatch.encode(to: &writer)

        let message = AapMessage(
            channel: Channel.ID_SEN,
            flags: AapFlags.NORMAL_MESSAGE,
            type: 0x8003,
            payload: writer.data
        )
        send(message: message)
    }

    public func sendNightModeEvent(isNight: Bool, force: Bool = false) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.startedSensors.contains(10) else { return }
            if !force && self.lastSentNightMode == isNight { return }
            self.lastSentNightMode = isNight
            let batch = SensorBatch(nightMode: [SensorBatch.NightData(isNightMode: isNight)])
            var writer = ProtoWriter()
            batch.encode(to: &writer)
            let msg = AapMessage(
                channel: Channel.ID_SEN,
                flags: AapFlags.NORMAL_MESSAGE,
                type: 0x8003,
                payload: writer.data
            )
            self.sendOnProcessingQueue(message: msg)
        }
    }

    private func appendBigEndianTimestampMs(to data: inout Data) {
        var value = UInt64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
        var bytes = [UInt8](repeating: 0, count: 8)
        for i in (0..<8).reversed() {
            bytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }
        data.append(contentsOf: bytes)
    }

    private func sendEncryptedRawStream(channel: UInt8, flags: UInt8, payload: Data) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.recordAapTrace(direction: "TX", channel: channel, flags: flags, type: 0, payloadSize: payload.count)

            guard let encryptedPayload = self.tlsHandler.encrypt(data: payload) else {
                AppLog.w("Failed to encrypt raw stream for channel \(Channel.name(for: channel))", tag: "AapTransport")
                self.registerTlsEncryptFailure(context: "raw-stream-\(Channel.name(for: channel))")
                return
            }
            self.consecutiveTlsEncryptFailures = 0

            var packet = Data()
            packet.append(channel)
            packet.append(flags)

            let encLen = UInt16(encryptedPayload.count)
            packet.append(UInt8((encLen >> 8) & 0xFF))
            packet.append(UInt8(encLen & 0xFF))
            packet.append(encryptedPayload)

            self.connection.send(packet)
        }
    }

    private func handleReceivedData(_ data: Data) {
        if state == .authenticating || state == .authenticatingComplete || state == .binding || state == .running {
            appendAndProcessEncryptedBuffer(data)
        } else {
            if state == .waitingForVersion {
                let preview = data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
                AppLog.i("waitingForVersion recv \(data.count) bytes, preview=\(preview)", tag: "AapTransport")
            }
            appendAndProcessBuffer(data)
        }
    }

    private func appendAndProcessEncryptedBuffer(_ data: Data) {
        bufferLock.lock()
        encryptedReceiveBuffer.append(data)
        bufferLock.unlock()
        processEncryptedBuffer()
    }

    private func processEncryptedBuffer() {
        var packets: [(channel: UInt8, flags: UInt8, declaredTotal: Int, encryptedPayload: Data)] = []

        bufferLock.lock()
        var offset = 0
        let totalCount = encryptedReceiveBuffer.count

        while offset + 4 <= totalCount {
            let channel = encryptedReceiveBuffer[offset]
            let flags = encryptedReceiveBuffer[offset + 1]
            let encLen = Int(UInt16(encryptedReceiveBuffer[offset + 2]) << 8 | UInt16(encryptedReceiveBuffer[offset + 3]))

            if encLen <= 0 || encLen > AapMessage.DEF_BUFFER_LENGTH {
                AppLog.w("Resync encrypted parser, dropped byte 0x\(String(format: "%02x", encryptedReceiveBuffer[offset]))", tag: "AapTransport")
                offset += 1
                continue
            }

            let carriesTotal = AapMessageFraming.carriesTotalLength(flags)
            let headerExtra = carriesTotal ? 4 : 0
            let packetSize = 4 + headerExtra + encLen
            if offset + packetSize > totalCount {
                break
            }

            var declaredTotal = 0
            if carriesTotal {
                let b4 = UInt32(encryptedReceiveBuffer[offset + 4])
                let b5 = UInt32(encryptedReceiveBuffer[offset + 5])
                let b6 = UInt32(encryptedReceiveBuffer[offset + 6])
                let b7 = UInt32(encryptedReceiveBuffer[offset + 7])
                declaredTotal = Int(b4 << 24 | b5 << 16 | b6 << 8 | b7)
            }

            let payloadStart = offset + 4 + headerExtra
            let payloadEnd = payloadStart + encLen
            let encryptedPayload = encryptedReceiveBuffer.subdata(in: payloadStart..<payloadEnd)
            packets.append((channel: channel, flags: flags, declaredTotal: declaredTotal, encryptedPayload: encryptedPayload))
            offset += packetSize
        }

        if offset > 0 {
            encryptedReceiveBuffer.removeSubrange(0..<offset)
        }
        bufferLock.unlock()

        for packet in packets {
            if (packet.flags & 0x08) != 0x08 {
                AppLog.w("Invalid encrypted flags=0x\(String(format: "%02x", packet.flags))", tag: "AapTransport")
                continue
            }

            guard let decrypted = tlsHandler.decrypt(data: packet.encryptedPayload) else {
                AppLog.i("Decrypt returned nil for encrypted payload len=\(packet.encryptedPayload.count)", tag: "AapTransport")
                registerTlsDecryptFailure(context: "payload-len-\(packet.encryptedPayload.count)")
                continue
            }
            consecutiveTlsDecryptFailures = 0
            lastInboundPacketUptime = ProcessInfo.processInfo.systemUptime

            if let audit = fragmentAudit.onMessage(
                channel: Int(packet.channel),
                flags: packet.flags,
                plaintextLength: decrypted.count,
                declaredTotal: packet.declaredTotal
            ) {
                AppLog.i("Fragmented message audit: \(audit)", tag: "AapTransport")
                if AuditRecoveryPolicy.shouldRequestKeyframe(outcome: audit.outcome, channel: audit.channel) {
                    requestVideoRecoveryIfNeeded(reason: "audit-\(audit.outcome)", ignoreRecentVideoGuard: true, isWireCorruption: true)
                }
            }

            let carriesType = AapMessageFraming.carriesMessageType(packet.flags)
            let msgType: Int
            if carriesType && decrypted.count >= 2 {
                msgType = (Int(decrypted[0]) << 8) | Int(decrypted[1])
            } else {
                msgType = -1
            }
            let dataOffset = carriesType ? 2 : 0

            let fragment = AapMessage(
                channel: Int(packet.channel),
                flags: packet.flags,
                type: msgType,
                dataOffset: dataOffset,
                size: decrypted.count,
                data: decrypted
            )

            do {
                if let message = try reassembler.accept(fragment: fragment, declaredTotal: packet.declaredTotal) {
                    if packet.channel == Channel.ID_VID {
                        if message.type == 0 {
                            recordVideoMessageType(0)
                        } else if message.type == 1 {
                            recordVideoMessageType(1, payload: message.payload)
                        }
                    }
                    handleMessage(message)
                }
            } catch {
                AppLog.w("Reassembly error: \(error)", tag: "AapTransport")
            }
            flushPendingTouchEventsOnProcessingQueue()
        }
        flushPendingTouchEventsOnProcessingQueue()
    }

    private func registerTlsDecryptFailure(context: String) {
        consecutiveTlsDecryptFailures += 1
        if consecutiveTlsDecryptFailures >= maxConsecutiveTlsFailures {
            failTransportForTlsErrors(reason: "decrypt-failure-\(context)")
        }
    }

    private func registerTlsEncryptFailure(context: String) {
        consecutiveTlsEncryptFailures += 1
        if consecutiveTlsEncryptFailures >= maxConsecutiveTlsFailures {
            failTransportForTlsErrors(reason: "encrypt-failure-\(context)")
        }
    }

    private func failTransportForTlsErrors(reason: String) {
        if case .error = state {
            return
        }

        AppLog.w("Too many TLS failures, forcing disconnect, reason=\(reason)", tag: "AapTransport")
        dumpRecentAapTrace(reason: reason)
        setState(.error("TLS stream failure (\(reason))"))
        connection.disconnect()
        delegate?.aapTransportDidDisconnect(self)
    }

    private func isMediaChannel(_ channel: UInt8) -> Bool {
        return channel == Channel.ID_VID || Channel.isAudio(channel)
    }

    private func isMediaStreamFlags(_ flags: UInt8) -> Bool {
        return flags == 0x08 || flags == 0x09 || flags == 0x0a || flags == 0x0b
    }

    private func isKnownMediaMsgType(_ type: UInt16) -> Bool {
        switch type {
        case 0, 1, 0x8000, 0x8001, 0x8002, 0x8003, 0x8004, 0x8005, 0x8006, 0x8007, 0x8008, 0x8009, 0x800A, 0x800B:
            return true
        default:
            return false
        }
    }

    private func shouldTreatAsMediaControl(flags: UInt8, type: UInt16, payloadSize: Int) -> Bool {
        guard isKnownMediaMsgType(type) else {
            return false
        }

        if flags == 0x08 || flags == 0x09 || flags == 0x0a {
            return false
        }

        return payloadSize <= 512
    }

    private func recordVideoMessageType(_ type: UInt16, payload: Data? = nil) {
        videoDiagnosticsLock.lock()
        if type == 1 {
            videoCodecConfigMessageCount += 1
            if let payload = payload {
                lastVideoCodecConfigPrefix = payload.prefix(24)
                    .map { String(format: "%02x", $0) }
                    .joined(separator: " ")
            }
        } else {
            videoDataMessageCount += 1
        }
        videoDiagnosticsLock.unlock()
    }

    private func appendAndProcessBuffer(_ data: Data) {
        bufferLock.lock()
        receiveBuffer.append(data)
        bufferLock.unlock()
        processBuffer()
    }

    private func processBuffer() {
        while true {
            var messageData: Data?

            bufferLock.lock()
            if receiveBuffer.count >= AapMessage.FRAME_HEADER_SIZE {
                let channel = receiveBuffer[0]
                let length = UInt16(receiveBuffer[2]) << 8 | UInt16(receiveBuffer[3])
                let totalMessageSize = Int(length) + 4

                let invalidChannel = channel > Channel.ID_WIFI
                let invalidLength = length < 2 || totalMessageSize > AapMessage.DEF_BUFFER_LENGTH

                if invalidChannel || invalidLength {
                    let dropped = receiveBuffer.removeFirst()
                    AppLog.w("Resync frame parser, dropped byte 0x\(String(format: "%02x", dropped))", tag: "AapTransport")
                    bufferLock.unlock()
                    continue
                }

                if receiveBuffer.count >= totalMessageSize {
                    messageData = receiveBuffer.subdata(in: 0..<totalMessageSize)
                    receiveBuffer.removeSubrange(0..<totalMessageSize)
                }
            }
            bufferLock.unlock()

            guard let frame = messageData else {
                return
            }

            if let message = AapMessage(data: frame) {
                handleMessage(message)
            }
        }
    }

    private func beginTlsHandshake() {
        guard tlsIdentityReady else {
            setState(.error("TLS identity not loaded (cert/key missing in bundle)"))
            delegate?.aapTransportDidDisconnect(self)
            return
        }

        do {
            tlsHandshakeStartUptime = ProcessInfo.processInfo.systemUptime
            AppLog.category(.connectionHandshake, "[CONN] Starting TLS handshake with headunit server", tag: "AapTransport")
            let step = try tlsHandler.startHandshakeSession()
            processTlsHandshakeStep(step)
            startHandshakeTimeout(for: .tlsHandshaking)
        } catch {
            AppLog.w("Failed to start TLS handshake: \(error)", tag: "AapTransport")
            setState(.error("TLS handshake failed: \(error.localizedDescription)"))
            delegate?.aapTransportDidDisconnect(self)
        }
    }

    private func continueTlsHandshake(with payload: Data) {
        do {
            let step = try tlsHandler.continueHandshake(with: payload)
            processTlsHandshakeStep(step)
        } catch {
            AppLog.w("TLS handshake step failed: \(error)", tag: "AapTransport")
            setState(.error("TLS handshake failed: \(error.localizedDescription)"))
            delegate?.aapTransportDidDisconnect(self)
        }
    }

    private func processTlsHandshakeStep(_ step: OpenSslHandshakeStep) {
        if !step.outgoingData.isEmpty {
            let tlsPreview = step.outgoingData.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " ")
            let message = AapMessage(
                channel: Channel.ID_CTR,
                flags: 0x03,
                type: AapMessageType.MESSAGE_ENCAPSULATED_SSL.rawValue,
                payload: step.outgoingData
            )
            sendRaw(message.toData())
            AppLog.i("Sent encapsulated SSL payload: \(step.outgoingData.count) bytes, tlsPreview=\(tlsPreview)", tag: "AapTransport")
        }

        if step.isComplete {
            let durationMs = tlsHandshakeStartUptime > 0 ? (ProcessInfo.processInfo.systemUptime - tlsHandshakeStartUptime) * 1000.0 : 0
            AppLog.category(.connectionHandshake, "[CONN] TLS handshake completed in \(String(format: "%.1f", durationMs))ms", tag: "AapTransport")
            AppLog.i("TLS handshake completed", tag: "AapTransport")
            tlsHandler.postHandshakeReset()
            setState(.authenticating)
            sendStatusOk()
        }
    }

    func handleMessage(_ message: AapMessage) {
        let channelId = message.channelUInt8
        recordAapTrace(direction: "RX", channel: channelId, flags: message.flags, type: message.typeUInt16, payloadSize: message.payloadSize)
        noteInboundMessage(channel: Int(channelId), bytes: message.payloadSize)

        if channelId != Channel.ID_VID && !Channel.isAudio(channelId) && channelId != Channel.ID_MIC {
            AppLog.i("Received message on channel \(Channel.name(for: channelId)), type=\(message.type), size=\(message.payload.count)", tag: "AapTransport")
        }

        if message.typeUInt16 == AapMessageType.CHANNEL_OPEN_REQUEST.rawValue ||
           (channelId != Channel.ID_CTR && (message.flags & AapMessageFraming.FLAG_BIT_CONTROL) != 0 && isControlMessageType(message.typeUInt16)) {
            handleControlMessage(message)
            return
        }

        switch channelId {
        case Channel.ID_CTR:
            handleControlMessage(message)

        case Channel.ID_SEN:
            handleSensorMessage(message)

        case Channel.ID_INP:
            handleInputMessage(message)

        case Channel.ID_VID:
            handleVideoMessage(message)

        case Channel.ID_AUD, Channel.ID_AU1, Channel.ID_AU2:
            handleAudioMessage(message)

        case Channel.ID_MIC:
            handleMicrophoneMessage(message)

        case Channel.ID_MPB:
            handleMediaPlaybackMessage(message)

        case Channel.ID_NAV:
            handleNavigationMessage(message)

        default:
            AppLog.w("Unhandled channel \(channelId)", tag: "AapTransport")
        }
    }

    private func noteInboundMessage(channel: Int, bytes: Int) {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        lastInboundMessageMs = nowMs
        if let report = linkGapMonitor.onMessage(nowMs: nowMs) {
            AppLog.i("LinkGap: \(report)", tag: "AapTransport")
        }
        if let rateReport = inboundRateMonitor.onMessage(channel: channel, bytes: bytes, nowMs: nowMs) {
            AppLog.i("InboundRate: \(rateReport)", tag: "AapTransport")
        }
        let quiet: LinkGapMonitor.Report?
        if UInt8(channel) == Channel.ID_VID {
            quiet = videoGapMonitor.onMessage(nowMs: nowMs)
        } else if Channel.isAudio(UInt8(channel)) {
            quiet = audioGapMonitor.onMessage(nowMs: nowMs)
        } else {
            quiet = nil
        }
        if let q = quiet {
            AppLog.i("MediaGap: \(q)", tag: "AapTransport")
        }
    }

    private func handleMediaPlaybackMessage(_ message: AapMessage) {
        switch message.type {
        case 0x8001:
            handleMediaPlaybackStatus(message.payload)
        case 0x8002:
            AppLog.i("MPB input/start response packet size=\(message.payload.count)", tag: "AapTransport")
            break
        case 0x8003:
            handleMediaPlaybackMetadata(message)
        default:
            AppLog.w("MPB unhandled type=\(message.type) flags=\(message.flags) size=\(message.payload.count)", tag: "AapTransport")
        }
    }

    private func handleMediaPlaybackStatus(_ payload: Data) {
        var status: AapPlaybackStatus?
        do {
            var reader = ProtoReader(data: payload)
            let protoStatus = try MediaPlaybackStatus(from: &reader)
            let state = protoStatus.state.flatMap { AapPlaybackStatus.State(rawValue: UInt64($0.rawValue)) }
            status = AapPlaybackStatus(
                state: state,
                mediaSource: protoStatus.mediaSource,
                playbackSeconds: protoStatus.playbackSeconds.map { UInt64($0) }
            )
        } catch {
            AppLog.w("ProtoReader failed to decode MediaPlaybackStatus: \(error), fallback to ProtoWire", tag: "AapTransport")
            let stateValue = ProtoWire.extractFirstVarint(from: payload, fieldNumber: 1)
            let source = ProtoWire.extractFirstString(from: payload, fieldNumber: 2)
            let seconds = ProtoWire.extractFirstVarint(from: payload, fieldNumber: 3)
            status = AapPlaybackStatus(
                state: stateValue.flatMap { AapPlaybackStatus.State(rawValue: $0) },
                mediaSource: source,
                playbackSeconds: seconds
            )
        }
        guard let finalStatus = status else { return }
        AppLog.i("MPB status state=\(finalStatus.state.map { "\($0.rawValue)" } ?? "-") source='\(finalStatus.mediaSource ?? "")' seconds=\(finalStatus.playbackSeconds.map(String.init) ?? "-")", tag: "AapTransport")
        delegate?.aapTransport(self, didReceivePlaybackStatus: finalStatus)
    }

    private func handleMediaPlaybackMetadata(_ message: AapMessage) {
        let payload = message.payload
        guard !payload.isEmpty else { return }
        AppLog.i("MPB metadata packet flags=0x\(String(format: "%02x", message.flags)) size=\(payload.count)", tag: "AapTransport")
        var metadata: AapMediaMetadata?
        do {
            var reader = ProtoReader(data: payload)
            let protoMeta = try MediaMetaData(from: &reader)
            metadata = AapMediaMetadata(
                title: protoMeta.song,
                artist: protoMeta.artist,
                album: protoMeta.album,
                durationSeconds: protoMeta.durationSeconds.map { UInt64($0) },
                albumArt: protoMeta.albumArt
            )
        } catch {
            AppLog.w("ProtoReader failed to decode MediaMetaData: \(error), fallback to ProtoWire", tag: "AapTransport")
            metadata = AapMediaMetadata(
                title: ProtoWire.extractFirstString(from: payload, fieldNumber: 1),
                artist: ProtoWire.extractFirstString(from: payload, fieldNumber: 2),
                album: ProtoWire.extractFirstString(from: payload, fieldNumber: 3),
                durationSeconds: ProtoWire.extractFirstVarint(from: payload, fieldNumber: 6),
                albumArt: ProtoWire.extractFirstBytes(from: payload, fieldNumber: 4)
            )
        }
        guard let finalMeta = metadata else { return }
        AppLog.i("MPB metadata title='\(finalMeta.title ?? "")' artist='\(finalMeta.artist ?? "")' album='\(finalMeta.album ?? "")' artBytes=\(finalMeta.albumArt?.count ?? 0)", tag: "AapTransport")
        delegate?.aapTransport(self, didReceiveMediaMetadata: finalMeta)
    }

    private func handleNavigationMessage(_ message: AapMessage) {
        switch message.type {
        case 0x8003:
            let status = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1)
            AppLog.i("NAV status=\(status.map(String.init) ?? "-")", tag: "AapTransport")

        case 0x8004:
            let road = ProtoWire.extractFirstString(from: message.payload, fieldNumber: 1) ?? ""
            let side = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 2) ?? 0
            let nextTurn = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 3) ?? 0
            let turnNumber = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 5)
            let turnAngle = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 6)

            let sideName = navSideName(side)
            let eventName = navEventName(nextTurn)
            AppLog.i("NAV detail road='\(road)' side=\(sideName)(\(side)) next=\(eventName)(\(nextTurn)) turnNo=\(turnNumber.map(String.init) ?? "-") angle=\(turnAngle.map(String.init) ?? "-")", tag: "AapTransport")

        case 0x8005:
            let distance = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1)
            let time = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 2)
            AppLog.i("NAV distance/time distanceM=\(distance.map(String.init) ?? "-") etaSec=\(time.map(String.init) ?? "-")", tag: "AapTransport")

        default:
            let road = ProtoWire.extractFirstString(from: message.payload, fieldNumber: 1)
            let f1 = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1)
            let f2 = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 2)
            let f3 = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 3)
            AppLog.w("NAV unknown type=\(message.type) size=\(message.payload.count) road='\(road ?? "")' f1=\(f1.map(String.init) ?? "-") f2=\(f2.map(String.init) ?? "-") f3=\(f3.map(String.init) ?? "-")", tag: "AapTransport")
        }
    }

    private func navSideName(_ value: UInt64) -> String {
        switch value {
        case 1: return "LEFT"
        case 2: return "RIGHT"
        case 3: return "UNSPECIFIED"
        default: return "UNKNOWN"
        }
    }

    private func navEventName(_ value: UInt64) -> String {
        switch value {
        case 0: return "UNKNOWN"
        case 1: return "DEPART"
        case 2: return "NAME_CHANGE"
        case 3: return "SLIGHT_TURN"
        case 4: return "TURN"
        case 5: return "SHARP_TURN"
        case 6: return "UTURN"
        case 7: return "ON_RAMP"
        case 8: return "OFF_RAMP"
        case 9: return "FORK"
        case 10: return "MERGE"
        case 11: return "ROUNDABOUT_ENTER"
        case 12: return "ROUNDABOUT_EXIT"
        case 13: return "ROUNDABOUT_ENTER_EXIT"
        case 14: return "STRAIGHT"
        case 16: return "FERRY_BOAT"
        case 17: return "FERRY_TRAIN"
        case 18: return "DESTINATION"
        default: return "UNKNOWN"
        }
    }

    private func handleControlMessage(_ message: AapMessage) {
        let chan = message.channelUInt8
        switch message.typeUInt16 {
        case AapMessageType.VERSION_RESPONSE.rawValue:
            AppLog.i("Version response received", tag: "AapTransport")
            if let result = AapVersionNegotiation.parse(frame: message.data, length: message.size) {
                AppLog.i("Negotiated AAP version \(result.major).\(result.minor), status=\(result.statusName), supports16=\(result.supports16)", tag: "AapTransport")
            }
            delayedVersionStartWorkItem?.cancel()
            delayedVersionStartWorkItem = nil
            versionRetryWorkItem?.cancel()
            versionRetryWorkItem = nil
            setState(.versionSent)
            setState(.tlsHandshaking)
            beginTlsHandshake()

        case AapMessageType.MESSAGE_ENCAPSULATED_SSL.rawValue:
            if state == .tlsHandshaking {
                continueTlsHandshake(with: message.payload)
            }

        case AapMessageType.AUTH_COMPLETE.rawValue:
            AppLog.i("Auth complete received", tag: "AapTransport")
            if state == .authenticating {
                setState(.authenticatingComplete)
                setState(.binding)
            }

        case AapMessageType.SERVICE_DISCOVERY_REQUEST.rawValue:
            AppLog.i("Service discovery request received", tag: "AapTransport")
            sendServiceDiscoveryResponse()

        case AapMessageType.CHANNEL_OPEN_REQUEST.rawValue:
            AppLog.i("Channel open request received", tag: "AapTransport")
            sendChannelOpenResponse(on: chan)
            if state == .authenticating {
                setState(.authenticatingComplete)
                setState(.binding)
            }
            if state == .binding || state == .authenticatingComplete {
                setState(.running)
            }

        case AapMessageType.AUDIO_FOCUS_REQUEST.rawValue:
            sendAudioFocusNotification(for: message, on: chan)

        case AapMessageType.AUDIO_FOCUS_RESPONSE.rawValue:
            break

        case AapMessageType.CAR_CONNECTED_DEVICES_REQUEST.rawValue:
            AppLog.i("Car connected devices request received", tag: "AapTransport")
            sendCarConnectedDevicesResponse(on: chan, unsolicited: false)

        case AapMessageType.USER_SWITCH_REQUEST.rawValue:
            AppLog.i("User switch request received", tag: "AapTransport")
            sendUserSwitchResponse(on: chan)

        case AapMessageType.PING_REQUEST.rawValue:
            sendPingResponse(for: message, on: chan)

        case AapMessageType.PING_RESPONSE.rawValue:
            let rttMs = self.lastPingSentUptime > 0 ? (ProcessInfo.processInfo.systemUptime - self.lastPingSentUptime) * 1000.0 : 0
            AppLog.category(.connectionHandshake, "[CONN] Received PING_RESPONSE from phone, RTT=\(String(format: "%.1f", rttMs))ms", tag: "AapTransport")
            AppLog.category(.protocolControl, "[PROTO] Received PING_RESPONSE, RTT=\(String(format: "%.1f", rttMs))ms", tag: "AapTransport")

        case AapMessageType.NAV_FOCUS_REQUEST.rawValue:
            sendNavFocusNotification(on: chan)

        case 0x0018:
            let requestedMode = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 2) ?? 1
            if requestedMode == 2 || requestedMode == 3 {
                AppLog.i("Native exit requested on control channel (mode=\(requestedMode))", tag: "AapTransport")
                sendVideoFocusNotification(on: Channel.ID_VID, gain: false, unsolicited: false, reason: "control-video-focus-exit")
                delegate?.aapTransportDidRequestExit(self)
            } else if requestedMode == 1 || requestedMode == 4 {
                sendVideoFocusNotification(on: Channel.ID_VID, gain: true, unsolicited: false, reason: "control-video-focus-request")
            }

        case AapMessageType.BYEBYE_REQUEST.rawValue:
            let reason = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1)
            gracefulDisconnectLock.lock()
            peerDisconnectDiagnostic = reason.map { "ByeBye reason \($0)" } ?? "ByeBye without reason"
            gracefulDisconnectLock.unlock()
            sendByebyeResponse(on: chan)
            delegate?.aapTransportDidRequestExit(self)

        case AapMessageType.BYEBYE_RESPONSE.rawValue:
            AppLog.i("Received byebye response", tag: "AapTransport")
            finishGracefulDisconnect(reason: "response")
            delegate?.aapTransportDidRequestExit(self)

        case AapMessageType.CHANNEL_OPEN_RESPONSE.rawValue:
            AppLog.i("Channel open response received", tag: "AapTransport")
            setState(.running)

        default:
            AppLog.w("Unknown control message type: \(message.type)", tag: "AapTransport")
        }
    }

    private func handleSensorMessage(_ message: AapMessage) {
        if message.type == 0x8001 {
            var reqSensorType: Int?
            if let sensorTypeRaw = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1) {
                let sensorType = Int(sensorTypeRaw)
                reqSensorType = sensorType
                startedSensors.insert(sensorTypeRaw)

                if sensorType == 1 {
                    let shouldUseIpadGps = ProjectionSettings.gpsSource == .ipad
                    delegate?.aapTransport(self, didRequestLocationUpdates: shouldUseIpadGps)
                }
            }
            sendSensorStartResponse(on: message.channelUInt8)
            if reqSensorType == 10 {
                sendNightModeEvent(isNight: ProjectionSettings.effectiveIsNightMode(), force: true)
            }
            return
        }

        AppLog.w("Unhandled sensor message type=\(message.type)", tag: "AapTransport")
    }

    private func handleInputMessage(_ message: AapMessage) {
        if message.type == Int(AapMessageType.CHANNEL_OPEN_REQUEST.rawValue) {
            sendChannelOpenResponse(on: message.channelUInt8)
            return
        }
        if message.type == 0x8002 {
            sendInputBindingResponse(on: message.channelUInt8)
            return
        }

        AppLog.w("Unhandled input message type=\(message.type)", tag: "AapTransport")
    }

    private func sendServiceDiscoveryResponse() {
        let isRhd = ProjectionSettings.driverPosition == .right
        let useGps = ProjectionSettings.gpsSource == .ipad
        let message = AapServiceDiscoveryResponseMessage.make(
            screenConfig: HeadUnitScreenConfig.shared,
            fpsLimit: ProjectionSettings.effectiveFpsLimit.rawValue,
            rightHandDrive: isRhd,
            useGps: useGps,
            useMic: ProjectionSettings.effectiveUseIpadMic,
            requestedDpi: ProjectionSettings.effectiveDpi,
            enableAudioSink: ProjectionSettings.isAudioSinkEnabled
        )
        send(message: message)
        AppLog.category(
            .connectionHandshake,
            "[CONN] Sent ServiceDiscoveryResponse (\(message.size) bytes, res=\(HeadUnitScreenConfig.shared.negotiatedWidth)x\(HeadUnitScreenConfig.shared.negotiatedHeight), dpi=\(ProjectionSettings.effectiveDpi), useMic=\(ProjectionSettings.effectiveUseIpadMic), audioSink=\(ProjectionSettings.isAudioSinkEnabled))",
            tag: "AapTransport"
        )
        AppLog.i("Sent typed ServiceDiscoveryResponse (\(message.size) bytes, useMic=\(ProjectionSettings.effectiveUseIpadMic))", tag: "AapTransport")
    }

    private func sendChannelOpenResponse(on channel: UInt8) {
        let payload = Data([0x08, 0x00])
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.CHANNEL_OPEN_RESPONSE.rawValue,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent channel open response on channel \(Channel.name(for: channel))", tag: "AapTransport")

        if channel == Channel.ID_SEN {
            sendDrivingStatusUnrestricted(on: channel)
        }
    }

    private func sendAudioFocusNotification(for request: AapMessage, on channel: UInt8) {
        let requestType = ProtoWire.extractFirstVarint(from: request.payload, fieldNumber: 1) ?? 1
        let focusState: UInt64
        switch requestType {
        case 1:
            focusState = 1
        case 2, 3:
            focusState = 2
        case 4:
            focusState = 3
        default:
            focusState = 1
        }

        let payload = Data([0x08, UInt8(focusState & 0x7F)])
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.AUDIO_FOCUS_NOTIFICATION.rawValue,
            payload: payload
        )
        send(message: message)
        AppLog.i("Audio focus requestType=\(requestType) -> focusState=\(focusState)", tag: "AapTransport")
    }

    private func sendSensorStartResponse(on channel: UInt8) {
        let payload = Data([0x08, 0x00])
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: 0x8002,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent sensor start response", tag: "AapTransport")
    }

    private func sendInputBindingResponse(on channel: UInt8) {
        let payload = Data([0x08, 0x00])
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: 0x8003,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent input binding response", tag: "AapTransport")
    }

    private func sendDrivingStatusUnrestricted(on channel: UInt8) {
        let drivingStatusData = ProtoWire.fieldVarint(1, value: 0)
        let sensorBatch = ProtoWire.fieldBytes(13, value: drivingStatusData)
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.NORMAL_MESSAGE,
            type: 0x8003,
            payload: sensorBatch
        )
        send(message: message)
        AppLog.i("Sent driving status unrestricted", tag: "AapTransport")
    }

    private func sendVideoFocusNotification(on channel: UInt8, gain: Bool = true, unsolicited: Bool = true, reason: String) {
        let message = AapVideoFocusEventMessage.make(gain: gain, unsolicited: unsolicited)
        send(message: message)
        AppLog.i("Sent video focus notification gain=\(gain) unsolicited=\(unsolicited) reason=\(reason)", tag: "AapTransport")
    }

    public func performVideoFocusCycle(reason: String) {
        guard focusCycleLever.tryClaim() else {
            AppLog.i("Focus cycle already in flight, skipping redundant cycle", tag: "AapTransport")
            return
        }
        focusCyclesUsedThisSession += 1
        lastFocusCycleAtMs = Int64(uptimeMs())
        AppLog.category(.protocolControl, "[PROTO] Initiating VideoFocus cycle (reason: \(reason), cycle #\(focusCyclesUsedThisSession))", tag: "AapTransport")
        AppLog.i("Initiating VideoFocus release/regain cycle (reason: \(reason), cycle #\(focusCyclesUsedThisSession))", tag: "AapTransport")
        sendVideoFocusNotification(on: Channel.ID_VID, gain: false, reason: "cycle-release-\(reason)")

        processingQueue.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in
            guard let self = self else { return }
            self.sendVideoFocusNotification(on: Channel.ID_VID, gain: true, reason: "cycle-regain-\(reason)")
            self.focusCycleLever.release()
            AppLog.i("Completed VideoFocus release/regain cycle", tag: "AapTransport")
        }
    }

    public func requestVideoFocusCycle(reason: String = "watchdog-no-first-frame") {
        processingQueue.async { [weak self] in
            self?.performVideoFocusCycle(reason: reason)
        }
    }

    public func sendPingRequest() {
        processingQueue.async { [weak self] in
            guard let self = self, self.state == .running else { return }
            self.lastPingSentUptime = ProcessInfo.processInfo.systemUptime
            let payload = ProtoWire.fieldVarint(1, value: UInt64(self.uptimeMs()))
            let message = AapMessage(
                channel: Channel.ID_CTR,
                flags: AapFlags.CONTROL_MESSAGE,
                type: AapMessageType.PING_REQUEST.rawValue,
                payload: payload
            )
            self.send(message: message)
            AppLog.category(.connectionHandshake, "[CONN] Sent PING_REQUEST to headunit server", tag: "AapTransport")
            AppLog.category(.protocolControl, "[PROTO] Sent PING_REQUEST (uptimeMs=\(self.uptimeMs()))", tag: "AapTransport")
        }
    }

    public func handleDidEnterBackground() {
        processingQueue.async { [weak self] in
            guard let self = self, self.state == .running else { return }
            self.sendMediaAck(on: Channel.ID_VID, forceFlush: true)
            self.sendVideoFocusNotification(on: Channel.ID_VID, gain: false, unsolicited: true, reason: "app-entered-background")
            AppLog.category(.connectionHandshake, "[CONN] Paused video focus due to enter background", tag: "AapTransport")
        }
    }

    public func handleWillEnterForeground() {
        processingQueue.async { [weak self] in
            guard let self = self, self.state == .running else { return }
            self.videoAssemblyBuffer.removeAll(keepingCapacity: true)
            self.videoFirstFragmentAtMs = 0
            self.sendPingRequest()
            self.performVideoFocusCycle(reason: "app-will-enter-foreground")
            AppLog.category(.connectionHandshake, "[CONN] Resumed video focus & cycle, sent ping on enter foreground", tag: "AapTransport")
        }
    }

    func sendUpdateUiConfigRequest(left: Int, top: Int, right: Int, bottom: Int, uiTheme: Int32? = nil) {
        processingQueue.async { [weak self] in
            guard let self = self, self.state == .running, self.isVideoChannelStarted else { return }
            let message = UpdateUiConfigRequest.make(left: left, top: top, right: right, bottom: bottom, uiTheme: uiTheme)
            self.send(message: message)
            AppLog.category(.protocolControl, "[PROTO] Sent UpdateUiConfigRequest (0x8009) left=\(left) top=\(top) right=\(right) bottom=\(bottom) uiTheme=\(String(describing: uiTheme))", tag: "AapTransport")
            AppLog.i("Sent UpdateUiConfigRequest left=\(left) top=\(top) right=\(right) bottom=\(bottom)", tag: "AapTransport")
            self.sendVideoFocusNotification(on: Channel.ID_VID, gain: true, unsolicited: true, reason: "update-ui-config")
        }
    }

    private func sendCarConnectedDevicesResponse(on channel: UInt8, unsolicited: Bool) {
        let device = buildConnectedDevice(name: "CarAutoPad", id: 1)
        var payload = Data()
        payload += ProtoWire.fieldBytes(1, value: device)
        payload += ProtoWire.fieldVarint(2, value: unsolicited ? 1 : 0)
        payload += ProtoWire.fieldVarint(3, value: 1)

        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.CAR_CONNECTED_DEVICES_RESPONSE.rawValue,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent car connected devices response (unsolicited=\(unsolicited))", tag: "AapTransport")
    }

    private func sendUserSwitchResponse(on channel: UInt8) {
        let selectedDevice = buildConnectedDevice(name: "CarAutoPad", id: 1)
        var payload = Data()
        payload += ProtoWire.fieldVarint(1, value: 0)
        payload += ProtoWire.fieldBytes(2, value: selectedDevice)

        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.USER_SWITCH_RESPONSE.rawValue,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent user switch response", tag: "AapTransport")
    }

    private func buildConnectedDevice(name: String, id: UInt64) -> Data {
        return ProtoWire.fieldString(1, value: name)
            + ProtoWire.fieldVarint(2, value: id)
    }

    private func sendPingResponse(for request: AapMessage, on channel: UInt8) {
        let timestamp = ProtoWire.extractFirstVarint(from: request.payload, fieldNumber: 1) ?? UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
        let payload = ProtoWire.fieldVarint(1, value: timestamp)
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.PING_RESPONSE.rawValue,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent ping response", tag: "AapTransport")
    }

    private func sendNavFocusNotification(on channel: UInt8) {
        let payload = ProtoWire.fieldVarint(1, value: 2)
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.NAV_FOCUS_NOTIFICATION.rawValue,
            payload: payload
        )
        send(message: message)
        AppLog.i("Sent navigation focus notification", tag: "AapTransport")
    }

    private func sendByebyeResponse(on channel: UInt8) {
        let message = AapMessage(
            channel: channel,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.BYEBYE_RESPONSE.rawValue,
            payload: Data()
        )
        send(message: message)
        AppLog.i("Sent byebye response", tag: "AapTransport")
    }

    private func finishGracefulDisconnect(reason: String) {
        gracefulDisconnectLock.lock()
        let completion = gracefulDisconnectCompletion
        gracefulDisconnectCompletion = nil
        switch reason {
        case "response":
            gracefulDisconnectDiagnostic = "Response received"
        case "write-timeout":
            gracefulDisconnectDiagnostic = "Timed out before byebye reached the wire"
        default:
            gracefulDisconnectDiagnostic = "Timed out waiting for response"
        }
        let timeout = gracefulDisconnectTimeout
        gracefulDisconnectTimeout = nil
        gracefulDisconnectLock.unlock()
        timeout?.cancel()
        guard let completion else { return }
        AppLog.i("Graceful disconnect finished via \(reason)", tag: "AapTransport")
        DispatchQueue.main.async(execute: completion)
    }

    private func cancelGracefulDisconnect() {
        gracefulDisconnectLock.lock()
        if gracefulDisconnectCompletion != nil {
            gracefulDisconnectDiagnostic = "Transport closed before response"
        }
        gracefulDisconnectCompletion = nil
        let timeout = gracefulDisconnectTimeout
        gracefulDisconnectTimeout = nil
        gracefulDisconnectLock.unlock()
        timeout?.cancel()
    }

enum ProtoWire {
    static func fieldVarint(_ fieldNumber: Int, value: UInt64) -> Data {
        var data = Data()
        data.append(contentsOf: encodeVarint(UInt64(fieldNumber << 3)))
        data.append(contentsOf: encodeVarint(value))
        return data
    }

    static func fieldBytes(_ fieldNumber: Int, value: Data) -> Data {
        var data = Data()
        data.append(contentsOf: encodeVarint(UInt64((fieldNumber << 3) | 2)))
        data.append(contentsOf: encodeVarint(UInt64(value.count)))
        data.append(value)
        return data
    }

    static func fieldString(_ fieldNumber: Int, value: String) -> Data {
        return fieldBytes(fieldNumber, value: Data(value.utf8))
    }

    static func extractFirstVarint(from payload: Data, fieldNumber: Int) -> UInt64? {
        let bytes = [UInt8](payload)
        var idx = 0
        while idx < bytes.count {
            guard let (key, next) = decodeVarint(bytes, start: idx) else { return nil }
            idx = next
            let wireType = Int(key & 0x07)
            let field = Int(key >> 3)

            if field == fieldNumber && wireType == 0 {
                guard let (value, end) = decodeVarint(bytes, start: idx) else { return nil }
                idx = end
                return value
            }

            switch wireType {
            case 0:
                guard let (_, end) = decodeVarint(bytes, start: idx) else { return nil }
                idx = end
            case 2:
                guard let (len, end) = decodeVarint(bytes, start: idx) else { return nil }
                idx = end + Int(len)
                if idx > bytes.count { return nil }
            default:
                return nil
            }
        }
        return nil
    }

    static func extractFirstString(from payload: Data, fieldNumber: Int) -> String? {
        guard let data = extractFirstBytes(from: payload, fieldNumber: fieldNumber) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func extractFirstBytes(from payload: Data, fieldNumber: Int) -> Data? {
        let bytes = [UInt8](payload)
        var idx = 0
        while idx < bytes.count {
            guard let (key, next) = decodeVarint(bytes, start: idx) else { return nil }
            idx = next
            let wireType = Int(key & 0x07)
            let field = Int(key >> 3)

            if wireType == 2 {
                guard let (len, end) = decodeVarint(bytes, start: idx) else { return nil }
                idx = end
                let endIdx = idx + Int(len)
                guard endIdx <= bytes.count else { return nil }

                if field == fieldNumber {
                    return Data(bytes[idx..<endIdx])
                }
                idx = endIdx
                continue
            }

            switch wireType {
            case 0:
                guard let (_, end) = decodeVarint(bytes, start: idx) else { return nil }
                idx = end
            default:
                return nil
            }
        }
        return nil
    }

    private static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var bytes: [UInt8] = []
        var v = value
        while v >= 0x80 {
            bytes.append(UInt8((v & 0x7f) | 0x80))
            v >>= 7
        }
        bytes.append(UInt8(v))
        return bytes
    }

    private static func decodeVarint(_ bytes: [UInt8], start: Int) -> (UInt64, Int)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var idx = start

        while idx < bytes.count {
            let b = bytes[idx]
            value |= UInt64(b & 0x7f) << shift
            idx += 1
            if (b & 0x80) == 0 {
                return (value, idx)
            }
            shift += 7
            if shift > 63 {
                return nil
            }
        }

        return nil
    }
}
    private func handleVideoMessage(_ message: AapMessage) {
        switch message.type {
        case Int(AapMessageType.CHANNEL_OPEN_REQUEST.rawValue):
            sendChannelOpenResponse(on: message.channelUInt8)

        case 0x8000:
            if mediaSessionIds[message.channelUInt8] == nil {
                mediaSessionIds[message.channelUInt8] = 0
            }
            sendMediaConfig(on: message.channelUInt8)
            sendVideoFocusNotification(on: message.channelUInt8, reason: "video-setup")

        case 0x8001:
            isVideoChannelStarted = true
            setMediaSessionId(fromStartPayload: message.payload, on: message.channelUInt8)
            if state != .running {
                setState(.running)
            }
            sendVideoFocusNotification(on: message.channelUInt8, reason: "video-start")
            sendNightModeEvent(isNight: ProjectionSettings.effectiveIsNightMode(), force: false)

            processingQueue.asyncAfter(deadline: .now() + .milliseconds(1200)) { [weak self] in
                guard let self = self, self.state == .running, self.isVideoChannelStarted else { return }
                let packetCount: Int = {
                    self.videoDiagnosticsLock.lock()
                    defer { self.videoDiagnosticsLock.unlock() }
                    return self.videoPacketCount
                }()
                if packetCount == 0 {
                    AppLog.w("Cold-start watchdog: 0 video packets received 1.2s after video-start. Cycling video focus.", tag: "AapTransport")
                    self.performVideoFocusCycle(reason: "cold-start-no-stream")
                }
            }

        case 0x8002:
            isVideoChannelStarted = false
            sendMediaAck(on: message.channelUInt8, forceFlush: true)
            break

        case 0x8007:
            let requestedMode = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 2) ?? 1
            if requestedMode == 2 || requestedMode == 3 {
                AppLog.i("Native exit requested via VIDEO_FOCUS_REQUEST (mode=\(requestedMode))", tag: "AapTransport")
                sendVideoFocusNotification(on: Channel.ID_VID, gain: false, unsolicited: false, reason: "video-focus-exit")
                delegate?.aapTransportDidRequestExit(self)
            } else if requestedMode == 1 || requestedMode == 4 {
                sendVideoFocusNotification(on: message.channelUInt8, gain: true, unsolicited: false, reason: "video-focus-request")
            }

        case 0, 1:
            processVideoStreamPacket(message)
            if message.type == 0 && AapMessageFraming.isLast(message.flags) {
                sendMediaAck(on: message.channelUInt8)
            }

        case Int(AapMessageType.VIDEO_FRAME.rawValue):
            processVideoPayloadAsSingleFrame(message.payload, hasTimestamp: false)

        default:
            break
        }
    }

    private func processVideoStreamPacket(_ message: AapMessage) {
        let flags = message.flags
        let payload = message.payload
        let hasTimestamp = (message.type == 0)
        let nowMs = uptimeMs()
        lastVideoPacketRxAtMs = nowMs
        videoDiagnosticsLock.lock()
        videoPacketCount += 1
        videoDiagnosticsLock.unlock()

        if videoFirstFragmentAtMs > 0,
           nowMs > videoFirstFragmentAtMs,
           nowMs - videoFirstFragmentAtMs > videoAssemblyTimeoutMs,
           flags == 0x09 {
            AppLog.w("Video assembly timeout \(nowMs - videoFirstFragmentAtMs)ms, dropping stale fragments", tag: "AapTransport")
            videoAssemblyBuffer.removeAll(keepingCapacity: true)
            videoAssemblyMessageType = 0
            videoFirstFragmentAtMs = 0
            requestVideoRecoveryIfNeeded(reason: "assembly-timeout", ignoreRecentVideoGuard: false, isWireCorruption: true)
        }

        switch flags {
        case 0x0b:
            videoAssemblyBuffer.removeAll(keepingCapacity: true)
            videoAssemblyMessageType = 0
            videoFirstFragmentAtMs = 0
            processVideoPayloadAsSingleFrame(payload, hasTimestamp: hasTimestamp)

        case 0x09:
            videoFirstFragmentAtMs = nowMs
            videoAssemblyMessageType = message.typeUInt16
            videoAssemblyBuffer.removeAll(keepingCapacity: true)
            if hasTimestamp {
                if payload.count > 8 {
                    videoAssemblyBuffer.append(payload.subdata(in: 8..<payload.count))
                }
            } else {
                videoAssemblyBuffer.append(payload)
            }

        case 0x08:
            if videoFirstFragmentAtMs == 0 {
                AppLog.i("Orphan middle video fragment received", tag: "AapTransport")
                requestVideoRecoveryIfNeeded(reason: "orphan-middle-fragment", ignoreRecentVideoGuard: false, isWireCorruption: true)
                return
            }
            if videoAssemblyBuffer.count + payload.count > maxVideoAssemblyBytes {
                AppLog.w("Video assembly overflow on middle fragment, dropping", tag: "AapTransport")
                videoAssemblyBuffer.removeAll(keepingCapacity: true)
                videoAssemblyMessageType = 0
                videoFirstFragmentAtMs = 0
                requestVideoRecoveryIfNeeded(reason: "assembly-overflow-middle", ignoreRecentVideoGuard: false, isWireCorruption: true)
                return
            }
            videoAssemblyBuffer.append(payload)

        case 0x0a:
            if videoAssemblyBuffer.count + payload.count > maxVideoAssemblyBytes {
                AppLog.w("Video assembly overflow on final fragment, dropping", tag: "AapTransport")
                videoAssemblyBuffer.removeAll(keepingCapacity: true)
                videoAssemblyMessageType = 0
                videoFirstFragmentAtMs = 0
                requestVideoRecoveryIfNeeded(reason: "assembly-overflow-final", ignoreRecentVideoGuard: false, isWireCorruption: true)
                return
            }
            videoFirstFragmentAtMs = 0
            videoAssemblyBuffer.append(payload)
            if !videoAssemblyBuffer.isEmpty {
                processVideoPayloadAsSingleFrame(videoAssemblyBuffer, hasTimestamp: false)
            }
            videoAssemblyBuffer.removeAll(keepingCapacity: true)
            videoAssemblyMessageType = 0

        default:
            processVideoPayloadAsSingleFrame(payload, hasTimestamp: hasTimestamp)
        }
    }

    private func processVideoPayloadAsSingleFrame(_ payload: Data, hasTimestamp: Bool = false) {
        lastVideoPacketRxAtMs = uptimeMs()
        let videoBytes: Data
        if hasTimestamp {
            guard payload.count > 8 else { return }
            videoBytes = payload.subdata(in: 8..<payload.count)
        } else {
            videoBytes = payload
        }
        guard !videoBytes.isEmpty else { return }

        if let offset = findAnnexBStartOffset(in: videoBytes) {
            deliverVideoFrame(offset == 0 ? videoBytes : videoBytes.subdata(in: offset..<videoBytes.count))
        } else if let parameterSets = H264NALParser.annexBParameterSets(from: videoBytes) {
            AppLog.i("Normalized non-Annex-B H.264 codec configuration", tag: "AapTransport")
            deliverVideoFrame(parameterSets)
        }
    }

    private func deliverVideoFrame(_ frame: Data) {
        let nowMs = uptimeMs()
        let nowUptime = ProcessInfo.processInfo.systemUptime
        videoNetStatsLock.lock()
        netRxVideoFrames1s += 1
        netRxVideoBytes1s += frame.count
        if lastVideoFrameRxUptime > 0 {
            let gapMs = (nowUptime - lastVideoFrameRxUptime) * 1000.0
            if gapMs > maxNetInterFrameGapMs1s {
                maxNetInterFrameGapMs1s = gapMs
            }
        }
        lastVideoFrameRxUptime = nowUptime
        videoNetStatsLock.unlock()

        if unrepairedSinceAtMs > 0 && (nowMs > lastVideoRecoveryRequestAtMs) && (nowMs - lastVideoRecoveryRequestAtMs > 500) {
            unrepairedSinceAtMs = 0
        }
        videoDiagnosticsLock.lock()
        completedVideoFrameCount += 1
        lastCompletedVideoFrameBytes = frame.count
        videoDiagnosticsLock.unlock()
        delegate?.aapTransport(self, didReceiveVideoData: frame)
    }

    private func findAnnexBStartOffset(in data: Data) -> Int? {
        guard data.count >= 3 else { return nil }
        return data.withUnsafeBytes { rawBuffer -> Int? in
            guard let ptr = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let maxScan = min(data.count, 64)
            var i = 0
            while i + 3 <= maxScan {
                if ptr[i] == 0x00 && ptr[i + 1] == 0x00 {
                    if ptr[i + 2] == 0x01 {
                        return i
                    }
                    if i + 4 <= maxScan && ptr[i + 2] == 0x00 && ptr[i + 3] == 0x01 {
                        return i
                    }
                }
                i += 1
            }
            return nil
        }
    }

    private func handleAudioMessage(_ message: AapMessage) {
        switch message.type {
        case Int(AapMessageType.CHANNEL_OPEN_REQUEST.rawValue):
            sendChannelOpenResponse(on: message.channelUInt8)

        case 0x8000:
            if mediaSessionIds[message.channelUInt8] == nil {
                mediaSessionIds[message.channelUInt8] = 0
            }
            if let codecVal = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1) {
                let codec = AudioSinkCodecPolicy.codec(for: Int(codecVal)) ?? .pcm
                sinkCodecs[message.channelUInt8] = codec
            } else {
                sinkCodecs[message.channelUInt8] = .pcm
            }
            sendMediaConfig(on: message.channelUInt8)
            sendAudioFocusGainUnsolicited()

        case 0x8001:
            setMediaSessionId(fromStartPayload: message.payload, on: message.channelUInt8)

        case 0x8002:
            audioAssemblyBuffers.removeValue(forKey: message.channelUInt8)
            sendMediaAck(on: message.channelUInt8, forceFlush: true)
            break

        case 0, 1:
            let isFirst = (message.flags & AapMessageFraming.FLAG_BIT_FIRST) != 0
            let isLast = (message.flags & AapMessageFraming.FLAG_BIT_LAST) != 0
            let channel = message.channelUInt8
            let isAac = sinkCodecs[channel]?.isAac ?? (ProjectionSettings.audioCodecPreference == .aac)

            if isFirst && isLast {
                if message.type == 0 {
                    sendMediaAck(on: channel)
                    if message.payload.count > 8 {
                        let audioData = message.payload.subdata(in: 8..<message.payload.count)
                        deliverAudioData(audioData, on: channel, isAac: isAac)
                    }
                } else {
                    sendMediaAck(on: channel)
                    if isAac && message.payload.count <= 16 {
                        delegate?.aapTransport(self, didReceiveAudioCodecConfig: message.payload, on: channel)
                    } else if !isAac && message.payload.count <= 8 {
                    } else if !message.payload.isEmpty {
                        deliverAudioData(message.payload, on: channel, isAac: isAac)
                    }
                }
            } else if isFirst && !isLast {
                let fragmentPayload: Data
                if message.type == 0 {
                    fragmentPayload = (message.payload.count > 8) ? message.payload.subdata(in: 8..<message.payload.count) : Data()
                } else {
                    fragmentPayload = message.payload
                }
                audioAssemblyBuffers[channel] = fragmentPayload
            } else if !isFirst && !isLast {
                audioAssemblyBuffers[channel]?.append(message.payload)
            } else if !isFirst && isLast {
                var buffer = audioAssemblyBuffers.removeValue(forKey: channel) ?? Data()
                buffer.append(message.payload)

                sendMediaAck(on: channel)

                if isAac && message.type == 1 && buffer.count <= 16 {
                    delegate?.aapTransport(self, didReceiveAudioCodecConfig: buffer, on: channel)
                } else if !isAac && message.type == 1 && buffer.count <= 8 {
                } else if !buffer.isEmpty {
                    deliverAudioData(buffer, on: channel, isAac: isAac)
                }
            }

        case Int(AapMessageType.AUDIO_FRAME.rawValue):
            sendMediaAck(on: message.channelUInt8)
            if message.payload.count > 8 {
                let audioData = message.payload.subdata(in: 8..<message.payload.count)
                let isAac = sinkCodecs[message.channelUInt8]?.isAac ?? false
                deliverAudioData(audioData, on: message.channelUInt8, isAac: isAac)
            }

        default:
            AppLog.w("Unhandled audio message type=\(message.type) on channel \(Channel.name(for: message.channelUInt8))", tag: "AapTransport")
        }
    }

    private func deliverAudioData(_ data: Data, on channel: UInt8, isAac: Bool) {
        guard ProjectionSettings.isAudioSinkEnabled else { return }
        guard !data.isEmpty else { return }
        if isAac {
            delegate?.aapTransport(self, didReceiveAudioData: data, on: channel, isAac: true)
        } else {
            let chCount = (channel == Channel.ID_AUD) ? 2 : 1
            let frameBytes = chCount * 2
            let alignedCount = (data.count / frameBytes) * frameBytes
            guard alignedCount > 0 else { return }
            let alignedData = (alignedCount == data.count) ? data : data.prefix(alignedCount)
            delegate?.aapTransport(self, didReceiveAudioData: alignedData, on: channel, isAac: false)
        }
    }

    private func handleMicrophoneMessage(_ message: AapMessage) {
        switch message.type {
        case 0x8000:
            AppLog.i("Microphone setup request received", tag: "AapTransport")
            sendMediaConfig(on: message.channelUInt8)

        case 0x8001:
            AppLog.i("Microphone start request received", tag: "AapTransport")
            setMediaSessionId(fromStartPayload: message.payload, on: message.channelUInt8)

        case 0x8002:
            AppLog.i("Microphone stop request received", tag: "AapTransport")
            delegate?.aapTransport(self, didRequestMicrophoneCapture: false)
            sendAudioFocusGainUnsolicited()

        case 0x8005:
            let openValue = ProtoWire.extractFirstVarint(from: message.payload, fieldNumber: 1) ?? 0
            let shouldOpen = openValue != 0
            AppLog.i("Microphone request open=\(shouldOpen), useIpadMic=\(ProjectionSettings.effectiveUseIpadMic)", tag: "AapTransport")
            if !ProjectionSettings.effectiveUseIpadMic {
                delegate?.aapTransport(self, didRequestMicrophoneCapture: false)
                if !shouldOpen {
                    sendAudioFocusGainUnsolicited()
                }
                sendMicrophoneResponse(on: message.channelUInt8, status: 0)
                break
            }
            delegate?.aapTransport(self, didRequestMicrophoneCapture: shouldOpen)
            if !shouldOpen {
                sendAudioFocusGainUnsolicited()
            }
            sendMicrophoneResponse(on: message.channelUInt8, status: 0)

        case 0x8006:
            break

        case 0x8004:
            break

        default:
            AppLog.w("Unhandled microphone message type=\(message.type)", tag: "AapTransport")
        }
    }

    private func sendMicrophoneResponse(on channel: UInt8, status: UInt64) {
        let sessionId = mediaSessionIds[channel] ?? 0
        let payload = ProtoWire.fieldVarint(1, value: status)
            + ProtoWire.fieldVarint(2, value: sessionId)

        let message = AapMessage(
            channel: channel,
            flags: AapFlags.NORMAL_MESSAGE,
            type: 0x8006,
            payload: payload
        )
        send(message: message)
    }

    private func setMediaSessionId(fromStartPayload payload: Data, on channel: UInt8) {
        let sessionId = ProtoWire.extractFirstVarint(from: payload, fieldNumber: 1) ?? 0
        mediaSessionIds[channel] = sessionId
        AppLog.i("Stored media session id \(sessionId) for channel \(Channel.name(for: channel))", tag: "AapTransport")

        if channel == Channel.ID_VID {
            let configIdx = Int(ProtoWire.extractFirstVarint(from: payload, fieldNumber: 2) ?? 0)
            HeadUnitScreenConfig.shared.adoptVideoConfig(at: configIdx)
        }
    }

    private func sendMediaAck(on channel: UInt8, forceFlush: Bool = false) {
        if !forceFlush {
            let count = (pendingMediaAcks[channel] ?? 0) + 1
            pendingMediaAcks[channel] = count
        }
        guard let count = pendingMediaAcks[channel], count > 0 else { return }

        let threshold: UInt32 = (channel == Channel.ID_VID) ? 1 : 2
        if count >= threshold || forceFlush {
            let sessionId = Int32(truncatingIfNeeded: mediaSessionIds[channel] ?? 0)
            let ackProto = MediaAck(sessionId: sessionId, ack: count)
            let payload = ackProto.serializedData()

            let message = AapMessage(
                channel: channel,
                flags: AapFlags.NORMAL_MESSAGE,
                type: 0x8004,
                payload: payload
            )
            self.sendOnProcessingQueue(message: message)
            pendingMediaAcks[channel] = 0
        }
    }

    private func requestVideoRecoveryIfNeeded(reason: String, ignoreRecentVideoGuard: Bool, isWireCorruption: Bool = false) {
        if DispatchQueue.getSpecific(key: processingQueueKey) == nil {
            processingQueue.async { [weak self] in
                self?.requestVideoRecoveryIfNeeded(reason: reason, ignoreRecentVideoGuard: ignoreRecentVideoGuard, isWireCorruption: isWireCorruption)
            }
            return
        }

        guard state == .running || state == .binding || state == .authenticatingComplete else {
            return
        }

        let nowMs = uptimeMs()
        if !ignoreRecentVideoGuard,
           lastVideoPacketRxAtMs > 0,
           nowMs > lastVideoPacketRxAtMs,
           nowMs - lastVideoPacketRxAtMs < 4_000 {
            return
        }

        if nowMs > lastVideoRecoveryRequestAtMs,
           nowMs - lastVideoRecoveryRequestAtMs < minVideoRecoveryIntervalMs {
            return
        }

        lastVideoRecoveryRequestAtMs = nowMs
        videoDiagnosticsLock.lock()
        videoRecoveryRequestCount += 1
        lastVideoRecoveryReason = reason
        videoDiagnosticsLock.unlock()

        let nowInt64 = Int64(nowMs)
        if unrepairedSinceAtMs == 0 {
            unrepairedSinceAtMs = nowInt64
        }
        if isWireCorruption {
            lastWireCorruptionAtMs = nowInt64
        }

        let action = KeyframeCycleEscalationPolicy.decide(
            nowMs: nowInt64,
            unrepairedSinceMs: unrepairedSinceAtMs,
            cyclesUsedThisSession: focusCyclesUsedThisSession,
            lastCycleMs: lastFocusCycleAtMs,
            lastWireCorruptionMs: lastWireCorruptionAtMs
        )

        switch action {
        case .nudge:
            AppLog.i("Requesting video recovery (nudge), reason=\(reason)", tag: "AapTransport")
            sendVideoFocusNotification(on: Channel.ID_VID, gain: true, reason: "recovery-\(reason)")
        case .cycleFocus:
            AppLog.i("Requesting video recovery (escalated cycle), reason=\(reason)", tag: "AapTransport")
            performVideoFocusCycle(reason: reason)
        case .waitForQuiet:
            AppLog.w("Wire corruption active, waiting for quiet before video recovery cycle", tag: "AapTransport")
            sendVideoFocusNotification(on: Channel.ID_VID, gain: true, reason: "recovery-quiet-\(reason)")
        }
    }

    private func uptimeMs() -> UInt64 {
        return DispatchTime.now().uptimeNanoseconds / 1_000_000
    }

    private func sendMediaConfig(on channel: UInt8) {
        let maxUnacked: UInt64 = (channel == Channel.ID_VID) ? 16 : (Channel.isAudio(channel) ? 30 : 8)
        let payload = ProtoWire.fieldVarint(1, value: 2)
            + ProtoWire.fieldVarint(2, value: maxUnacked)
            + ProtoWire.fieldVarint(3, value: 0)

        let message = AapMessage(
            channel: channel,
            flags: AapFlags.NORMAL_MESSAGE,
            type: 0x8003,
            payload: payload
        )
        send(message: message)
        if !Channel.isAudio(channel) && channel != Channel.ID_MIC && channel != Channel.ID_VID {
            AppLog.i("Sent media config on channel \(Channel.name(for: channel))", tag: "AapTransport")
        }
    }

    private func sendAudioFocusGainUnsolicited() {
        let payload = ProtoWire.fieldVarint(1, value: 1)
            + ProtoWire.fieldVarint(2, value: 1)

        let message = AapMessage(
            channel: Channel.ID_CTR,
            flags: AapFlags.CONTROL_MESSAGE,
            type: AapMessageType.AUDIO_FOCUS_NOTIFICATION.rawValue,
            payload: payload
        )
        send(message: message)
    }

    private func recordAapTrace(direction: String, channel: UInt8, flags: UInt8, type: UInt16, payloadSize: Int) {
        if (channel == Channel.ID_VID || Channel.isAudio(channel)) && (type == 0 || type == 1) {
            return
        }
        let ts = UInt64(Date().timeIntervalSince1970 * 1000)
        let entry = AapTraceEntry(
            timestampMs: ts,
            direction: direction,
            channel: channel,
            flags: flags,
            type: type,
            payloadSize: payloadSize
        )
        aapTraceLock.lock()
        lastAapTrace.append(entry)
        if lastAapTrace.count > maxAapTraceEntries {
            lastAapTrace.removeFirst(lastAapTrace.count - maxAapTraceEntries)
        }
        aapTraceLock.unlock()
    }

    private func dumpRecentAapTrace(reason: String) {
        aapTraceLock.lock()
        let traceSnapshot = lastAapTrace
        aapTraceLock.unlock()

        guard !traceSnapshot.isEmpty else {
            AppLog.w("No recent AAP trace before disconnect (\(reason))", tag: "AapTrace")
            return
        }

        let count = min(32, traceSnapshot.count)
        AppLog.w("Recent AAP trace before disconnect (\(reason), last \(count)):", tag: "AapTrace")
        for (idx, entry) in traceSnapshot.suffix(32).enumerated() {
            AppLog.w("  [\(idx + 1)] t=\(entry.timestampMs) \(entry.direction) ch=\(Channel.name(for: entry.channel))(\(entry.channel)) flags=0x\(String(format: "%02x", entry.flags)) type=\(entry.type) size=\(entry.payloadSize)", tag: "AapTrace")
        }
    }
}

extension AapTransport: ByteStreamConnectionDelegate {
    func byteStreamConnectionDidConnect(_ connection: ByteStreamConnection) {
        AppLog.i("byte stream connected, starting handshake", tag: "AapTransport")
        startHandshake()
    }

    func byteStreamConnection(_ connection: ByteStreamConnection, didReceive data: Data) {
        processingQueue.async { [weak self] in
            self?.handleReceivedData(data)
        }
    }

    func byteStreamConnection(_ connection: ByteStreamConnection, didDisconnect error: Error?) {
        cancelGracefulDisconnect()
        if let error {
            AppLog.w("byte stream error: \(error)", tag: "AapTransport")
            dumpRecentAapTrace(reason: "connection-error")
            setState(.error(error.localizedDescription))
        } else {
            AppLog.i("byte stream disconnected", tag: "AapTransport")
            dumpRecentAapTrace(reason: "connection-disconnect")
        }
        delayedVersionStartWorkItem?.cancel()
        delayedVersionStartWorkItem = nil
        versionRetryWorkItem?.cancel()
        versionRetryWorkItem = nil
        startedSensors.removeAll()
        lastSentNightMode = nil
        isVideoChannelStarted = false
        tlsHandler.releaseSessionOnly()
        delegate?.aapTransportDidDisconnect(self)
    }
}

public enum TouchAction: UInt8 {
    case DOWN = 0
    case UP = 1
    case MOVE = 2
    case CANCEL = 3
    case POINTER_DOWN = 5
    case POINTER_UP = 6
}

typealias ProtoWire = AapTransport.ProtoWire
