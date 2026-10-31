import UIKit
import AVFoundation
import CoreMedia
import VideoToolbox

public typealias VideoRendererView = H264VideoRendererView

public class H264VideoRendererView: UIView {

    public struct RendererDiagnostics {
        public var inputFrames = 0
        public var parsedFrames = 0
        public var spsNALs = 0
        public var ppsNALs = 0
        public var vpsNALs = 0
        public var idrFrames = 0
        public var formatDescriptions = 0
        public var formatFailures = 0
        public var missingConfigDrops = 0
        public var awaitingIDRDrops = 0
        public var sampleBuffers = 0
        public var sampleFailures = 0
        public var enqueuedSamples = 0
        public var notReadyDrops = 0
        public var layerFailures = 0
        public var queueDrops = 0
        public var lastNALTypes: [Int] = []
        public var activeCodec: String = "Unknown"
        public var concealedFrames = 0
        public var latencyReport: String = "None"
    }

    public var onFrameDisplayed: (() -> Void)?
    public var onKeyframeRequested: (() -> Void)?
    public var onCorruptionDetected: ((String) -> Void)?
    public var onVideoSizeResolved: ((CGSize) -> Void)?

    public var codecWidth: Int = 1920 {
        didSet { if codecWidth != oldValue { updateGeometry() } }
    }
    public var codecHeight: Int = 1080 {
        didSet { if codecHeight != oldValue { updateGeometry() } }
    }
    public var widthMargin: Int = 0 {
        didSet { if widthMargin != oldValue { updateGeometry() } }
    }
    public var heightMargin: Int = 0 {
        didSet { if heightMargin != oldValue { updateGeometry() } }
    }
    public var fitMode: VideoFitMode = .fillMargin {
        didSet { if fitMode != oldValue { updateGeometry() } }
    }

    private var lastNotifiedVideoSize: CGSize = .zero

    public let displayLayer = AVSampleBufferDisplayLayer()

    public var motionBlurMode: MotionBlurMode = ProjectionSettings.motionBlurMode {
        didSet {
            guard motionBlurMode != oldValue else { return }
            applySmoothingModeChange(to: motionBlurMode)
        }
    }

    private struct PacedSampleEntry {
        let sampleBuffer: CMSampleBuffer
        let ptsUs: Int64
        let isKeyframe: Bool
        let parseMs: Double
        let frameBytes: Int
    }

    private let pacedQueueLock = NSLock()
    private var pacedSampleQueue: [PacedSampleEntry] = []
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkTargetProxy?
    private var lastVSyncPresentUptime: TimeInterval = 0

    public var queuedPacedSampleCount: Int {
        pacedQueueLock.lock()
        defer { pacedQueueLock.unlock() }
        return pacedSampleQueue.count
    }

    public var isDisplayLinkActive: Bool {
        return displayLink != nil && !(displayLink?.isPaused ?? true)
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    public private(set) var pinnedCodec: VideoCodecType?

    public struct FrameReleasePacer {
        public var nextScheduledPtsSeconds: Double = 0

        public init(nextScheduledPtsSeconds: Double = 0) {
            self.nextScheduledPtsSeconds = nextScheduledPtsSeconds
        }

        public mutating func nextPts(nowSeconds: Double, frameInterval: Double = 1.0 / 60.0) -> Double {
            var targetSeconds = max(nowSeconds, nextScheduledPtsSeconds)
            if targetSeconds - nowSeconds > frameInterval * 2.5 {
                targetSeconds = nowSeconds
            }
            nextScheduledPtsSeconds = targetSeconds + frameInterval
            return targetSeconds
        }

        public mutating func reset() {
            nextScheduledPtsSeconds = 0
        }
    }

    public private(set) var isInBackground: Bool = false
    public var onProvideNetStats: (() -> (fps: Int, bytes: Int, maxGapMs: Double))?

    private var lastRenderUptime: TimeInterval = 0
    private var lastTelemetryUptime: TimeInterval = 0
    private var enqueuedFrames1s: Int = 0
    private var parseDurationMsSum1s: Double = 0
    private var maxParseMs1s: Double = 0
    private var layerWaitCount1s: Int = 0
    private var layerWaitDurationMsSum1s: Double = 0
    private var ptsLeadMsSum1s: Double = 0
    private var renderGapMaxMs1s: Double = 0
    private var qMax1s: Int = 0
    private var lastReportedQDrops: Int = 0
    private var lastReportedNotReadyDrops: Int = 0
    private var lastReportedAwaitingIdrDrops: Int = 0
    private var lastCalculatedPtsLeadMs: Double = 0

    private var formatDescription: CMVideoFormatDescription?
    private var vps: Data?
    private var sps: Data?
    private var pps: Data?
    private var frameIndex: Int64 = 0
    public private(set) var framePacer = FrameReleasePacer()
    public var nextScheduledPtsSeconds: Double {
        return framePacer.nextScheduledPtsSeconds
    }
    private var decodedFrameCount: Int = 0
    private var notReadyStreak = 0

    private let processQueue = DispatchQueue(label: "com.carautopad.videodecode", qos: .userInteractive)
    private let frameQueueLock = NSLock()
    private var pendingFrames: [Data] = []
    private var isProcessingFrame = false

    private let maxPendingFrames = 30
    private let maxPendingEssentialFrames = 60

    private var hasDecodedKeyframe = false
    private let diagnosticsLock = NSLock()
    private var diagnostics = RendererDiagnostics()

    private struct GeometryCache: Equatable {
        let bounds: CGRect
        let fitMode: VideoFitMode
        let codecW: Int
        let codecH: Int
        let marginW: Int
        let marginH: Int
        let streamSize: CGSize
    }
    private var lastAppliedGeometry: GeometryCache?

    private let keyframeRepairTracker = KeyframeRepairTracker()
    private let latencyMonitor = DecodeLatencyMonitor()
    private var concealmentState: CorruptionConcealmentPolicy.State = .armed
    private var concealmentWindowOpenedMs: Int64 = 0
    private var sessionHasRendered: Bool = false

    public private(set) var currentFps: Int = 0
    private var fpsFrameCount: Int = 0
    private var lastFpsTimestamp: TimeInterval = 0

    public var droppedFrames: Int {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }
        return diagnostics.queueDrops + diagnostics.notReadyDrops + diagnostics.missingConfigDrops
    }

    public var keyframeRepairs: Int {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }
        return diagnostics.concealedFrames
    }

    public var currentDiagnostics: RendererDiagnostics {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }
        return diagnostics
    }

    public var decodeLatency: (medianMs: Double, p95Ms: Double) {
        guard let rep = latencyMonitor.peekReport() else { return (0.0, 0.0) }
        return (Double(rep.medianUs) / 1000.0, Double(rep.p95Us) / 1000.0)
    }

    public var onDecoderFallbackRequested: ((_ currentWidth: Int, _ currentHeight: Int, _ reason: String) -> Void)?
    private var consecutiveDecodeFailures = 0
    private var hasTriggeredFallbackThisSession = false

    private func recordDecodeFailure(reason: String) {
        guard !sessionHasRendered && !hasTriggeredFallbackThisSession else { return }
        consecutiveDecodeFailures += 1
        if consecutiveDecodeFailures >= 8 {
            hasTriggeredFallbackThisSession = true
            let w = Int(lastNotifiedVideoSize.width > 0 ? lastNotifiedVideoSize.width : CGFloat(codecWidth))
            let h = Int(lastNotifiedVideoSize.height > 0 ? lastNotifiedVideoSize.height : CGFloat(codecHeight))
            AppLog.e("H264VideoRendererView: 8 consecutive decode failures detected (\(reason)), requesting fallback", tag: "VideoRenderer")
            DispatchQueue.main.async { [weak self] in
                self?.onDecoderFallbackRequested?(w, h, reason)
            }
        }
    }

    private let activeClipView = UIView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .black
        clipsToBounds = true
        isUserInteractionEnabled = false
        layer.masksToBounds = true
        activeClipView.clipsToBounds = true
        activeClipView.isUserInteractionEnabled = false
        addSubview(activeClipView)
        displayLayer.videoGravity = .resize
        activeClipView.layer.addSublayer(displayLayer)
        applyGeometry()
        if motionBlurMode != .off {
            ensureDisplayLinkStarted()
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        applyGeometry()
    }

    public func updateGeometry() {
        DispatchQueue.main.async { [weak self] in
            self?.applyGeometry()
        }
    }

    public func applyGeometry() {
        let viewBounds = self.bounds
        guard viewBounds.width > 0 && viewBounds.height > 0 else { return }

        let screenConfig = HeadUnitScreenConfig.shared
        let fitMode = self.fitMode
        var codecW = self.codecWidth > 0 ? self.codecWidth : screenConfig.getNegotiatedWidth()
        var codecH = self.codecHeight > 0 ? self.codecHeight : screenConfig.getNegotiatedHeight()
        var marginW = self.widthMargin
        var marginH = self.heightMargin

        let streamSize = lastNotifiedVideoSize
        if streamSize.width > 0 && streamSize.height > 0 {
            let streamIsLandscape = streamSize.width > streamSize.height
            let configCodecIsLandscape = codecW > codecH
            if streamIsLandscape != configCodecIsLandscape {
                codecW = Int(streamSize.width)
                codecH = Int(streamSize.height)
                marginW = 0
                marginH = 0
            }
        }

        let currentGeom = GeometryCache(
            bounds: viewBounds,
            fitMode: fitMode,
            codecW: codecW,
            codecH: codecH,
            marginW: marginW,
            marginH: marginH,
            streamSize: streamSize
        )
        if lastAppliedGeometry == currentGeom {
            return
        }
        lastAppliedGeometry = currentGeom

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let activeW = max(1, codecW - marginW)
        let activeH = max(1, codecH - marginH)

        let activeRect = ProjectionGeometryPolicy.activeDisplayRect(
            bounds: viewBounds,
            activeW: activeW,
            activeH: activeH,
            fitMode: fitMode
        )

        let boundsLandscape = viewBounds.width > viewBounds.height
        let activeLandscape = activeW > activeH
        let isMismatched = boundsLandscape != activeLandscape

        if marginW > 0 || marginH > 0 {
            activeClipView.frame = activeRect
            let overscanFrame = ProjectionGeometryPolicy.overscanLayerFrame(
                activeRect: CGRect(origin: .zero, size: activeRect.size),
                codecW: codecW,
                codecH: codecH,
                activeW: activeW,
                activeH: activeH
            )
            displayLayer.videoGravity = .resize
            displayLayer.frame = overscanFrame
        } else {
            activeClipView.frame = viewBounds
            displayLayer.frame = activeClipView.bounds
            switch fitMode {
            case .contain, .fit:
                displayLayer.videoGravity = .resizeAspect
                displayLayer.frame = activeRect
            case .cover:
                displayLayer.videoGravity = .resizeAspectFill
                displayLayer.frame = activeRect
            case .fill, .fillMargin:
                if isMismatched {
                    displayLayer.videoGravity = .resizeAspect
                } else {
                    displayLayer.videoGravity = .resize
                }
                displayLayer.frame = activeRect
            case .stretch:
                displayLayer.videoGravity = .resize
                displayLayer.frame = activeRect
            }
        }

        CATransaction.commit()
    }

    private func applySmoothingModeChange(to newValue: MotionBlurMode) {
        if newValue == .off {
            stopDisplayLink()
            var remaining: [PacedSampleEntry] = []
            pacedQueueLock.lock()
            remaining = pacedSampleQueue
            pacedSampleQueue.removeAll()
            lastVSyncPresentUptime = 0
            pacedQueueLock.unlock()

            if !remaining.isEmpty {
                processQueue.async { [weak self] in
                    guard let self = self else { return }
                    for entry in remaining {
                        self.submitSampleEntry(entry, displayImmediately: true, doNotDisplay: false)
                    }
                }
            }
        } else {
            ensureDisplayLinkStarted()
            onKeyframeRequested?()
        }
    }

    public func reset() {
        isInBackground = false

        diagnosticsLock.lock()
        diagnostics = RendererDiagnostics()
        diagnosticsLock.unlock()

        frameQueueLock.lock()
        pendingFrames.removeAll()
        isProcessingFrame = false
        frameQueueLock.unlock()

        keyframeRepairTracker.reset()
        latencyMonitor.reset()

        pacedQueueLock.lock()
        pacedSampleQueue.removeAll()
        lastVSyncPresentUptime = 0
        pacedQueueLock.unlock()
        pauseDisplayLink()

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.concealmentState = .armed
            self.concealmentWindowOpenedMs = 0
            self.sessionHasRendered = false
            self.consecutiveDecodeFailures = 0
            self.hasTriggeredFallbackThisSession = false
            self.frameIndex = 0
            self.framePacer.reset()
            self.decodedFrameCount = 0
            self.vps = nil
            self.sps = nil
            self.pps = nil
            self.formatDescription = nil
            self.hasDecodedKeyframe = false
            self.pinnedCodec = nil
            self.lastNotifiedVideoSize = .zero
        }

        if Thread.isMainThread {
            notReadyStreak = 0
            displayLayer.flushAndRemoveImage()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.notReadyStreak = 0
                self.displayLayer.flushAndRemoveImage()
            }
        }
    }

    public func enterBackground() {
        isInBackground = true
        frameQueueLock.lock()
        pendingFrames.removeAll()
        isProcessingFrame = false
        frameQueueLock.unlock()

        pacedQueueLock.lock()
        pacedSampleQueue.removeAll()
        lastVSyncPresentUptime = 0
        pacedQueueLock.unlock()
        pauseDisplayLink()

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.hasDecodedKeyframe = false
            self.notReadyStreak = 0
            self.framePacer.reset()
        }

        if Thread.isMainThread {
            displayLayer.flushAndRemoveImage()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.flushAndRemoveImage()
            }
        }
    }

    public func enterForeground() {
        isInBackground = false

        pacedQueueLock.lock()
        pacedSampleQueue.removeAll()
        lastVSyncPresentUptime = 0
        pacedQueueLock.unlock()
        if motionBlurMode != .off {
            resumeDisplayLink()
        }

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.hasDecodedKeyframe = false
            self.notReadyStreak = 0
            self.framePacer.reset()
            self.lastRenderUptime = 0
            self.lastTelemetryUptime = 0
        }

        if Thread.isMainThread {
            displayLayer.flushAndRemoveImage()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.flushAndRemoveImage()
            }
        }
    }

    public func enqueueAnnexBFrame(_ frame: Data) {
        guard !isInBackground, !frame.isEmpty else { return }
        updateDiagnostics { $0.inputFrames += 1 }
        enqueueFrameForProcessing(frame)
    }

    public func reportCorruption(reason: String) {
        onCorruptionDetected?(reason)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let outcome = CorruptionConcealmentPolicy.next(
            nowMs: nowMs,
            state: concealmentState,
            windowOpenedMs: concealmentWindowOpenedMs,
            corruptionReported: true,
            keyframeRepaired: false,
            sessionHasRendered: sessionHasRendered
        )
        if outcome == .open {
            concealmentState = .concealing
            concealmentWindowOpenedMs = nowMs
        }
        onKeyframeRequested?()
    }

    public func diagnosticLines() -> [String] {
        diagnosticsLock.lock()
        let snapshot = diagnostics
        diagnosticsLock.unlock()

        let nalTypes = snapshot.lastNALTypes.isEmpty
            ? "None"
            : snapshot.lastNALTypes.map(String.init).joined(separator: ",")

        let latencyStr = latencyMonitor.report()?.description ?? snapshot.latencyReport

        return [
            "Renderer active codec: \(snapshot.activeCodec)",
            "Renderer input frames: \(snapshot.inputFrames)",
            "Renderer parsed frames: \(snapshot.parsedFrames)",
            "Renderer VPS/SPS/PPS NALs: \(snapshot.vpsNALs)/\(snapshot.spsNALs)/\(snapshot.ppsNALs)",
            "Renderer IDR/IRAP frames: \(snapshot.idrFrames)",
            "Renderer format descriptions/failures: \(snapshot.formatDescriptions)/\(snapshot.formatFailures)",
            "Renderer drops missing config/awaiting IDR: \(snapshot.missingConfigDrops)/\(snapshot.awaitingIDRDrops)",
            "Renderer sample buffers/failures: \(snapshot.sampleBuffers)/\(snapshot.sampleFailures)",
            "Renderer enqueued/not-ready/layer failures: \(snapshot.enqueuedSamples)/\(snapshot.notReadyDrops)/\(snapshot.layerFailures)",
            "Renderer queue drops/concealed: \(snapshot.queueDrops)/\(snapshot.concealedFrames)",
            "Renderer last NAL types: \(nalTypes)",
            "Renderer latency: \(latencyStr)",
            "Renderer display status: \(displayStatusDescription())",
            "Renderer display error: \(displayLayer.error?.localizedDescription ?? "None")",
        ]
    }

    private func enqueueFrameForProcessing(_ frame: Data) {
        var droppedFrames = 0

        frameQueueLock.lock()
        let fps = ProjectionSettings.fpsLimit.rawValue == 1 ? 60 : 30
        let capacity = VideoFeedQueuePolicy.capacityFor(fpsLimit: fps)
        let dynamicMax = min(capacity, maxPendingFrames)

        if pendingFrames.count >= dynamicMax {
            if let dropIndex = pendingFrames.firstIndex(where: { !isEssentialFrame($0) }) {
                pendingFrames.remove(at: dropIndex)
                droppedFrames = 1
            } else if pendingFrames.count >= maxPendingEssentialFrames {
                pendingFrames.removeFirst()
                droppedFrames = 1
            }
        }
        pendingFrames.append(frame)

        let shouldStartProcessing = !isProcessingFrame
        if shouldStartProcessing {
            isProcessingFrame = true
        }
        frameQueueLock.unlock()

        if droppedFrames > 0 {
            updateDiagnostics { $0.queueDrops += droppedFrames }
            onKeyframeRequested?()
        }

        guard shouldStartProcessing else { return }
        processQueue.async { [weak self] in
            self?.processFrameLoop()
        }
    }

    private func processFrameLoop() {
        while true {
            let nextFrame: Data?
            frameQueueLock.lock()
            if pendingFrames.isEmpty {
                isProcessingFrame = false
                frameQueueLock.unlock()
                return
            }
            nextFrame = pendingFrames.removeFirst()
            frameQueueLock.unlock()

            guard let frame = nextFrame else { continue }
            processSingleFrame(frame)
        }
    }

    private func processSingleFrame(_ frame: Data) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let parseStartTime = ProcessInfo.processInfo.systemUptime
        let nalUnits = H264NALParser.nalUnits(from: frame)
        guard !nalUnits.isEmpty else { return }

        if pinnedCodec == nil {
            let isHevcStream = detectHevc(from: nalUnits)
            pinnedCodec = isHevcStream ? .hevc : .h264
            updateDiagnostics { $0.activeCodec = isHevcStream ? "HEVC (H.265)" : "H.264 (AVC)" }
        }
        let isHevc = (pinnedCodec == .hevc)

        var extractedVPS: Data?
        var extractedSPS: Data?
        var extractedPPS: Data?
        var nalTypeInts: [Int] = []
        var accessUnitNALs: [Data] = []
        var hasVclSlice = false
        var isKeyframe = false

        if isHevc {
            for nal in nalUnits {
                guard let first = nal.first else { continue }
                let nalType = Int((first & 0x7E) >> 1)
                nalTypeInts.append(nalType)
                if (16...21).contains(nalType) {
                    isKeyframe = true
                }
                if nalType == 32 {
                    extractedVPS = nal
                } else if nalType == 33 {
                    extractedSPS = nal
                } else if nalType == 34 {
                    extractedPPS = nal
                } else if nalType == 35 {
                    continue
                } else {
                    accessUnitNALs.append(nal)
                    if (0...21).contains(nalType) {
                        hasVclSlice = true
                    }
                }
            }
        } else {
            for nal in nalUnits {
                guard let first = nal.first else { continue }
                let nalType = Int(first & 0x1F)
                nalTypeInts.append(nalType)
                if nalType == 5 {
                    isKeyframe = true
                }
                if nalType == 7 {
                    extractedSPS = nal
                } else if nalType == 8 {
                    extractedPPS = nal
                } else if nalType == 9 {
                    continue
                } else {
                    accessUnitNALs.append(nal)
                    if (1...5).contains(nalType) {
                        hasVclSlice = true
                    }
                }
            }
        }

        updateDiagnostics {
            $0.parsedFrames += 1
            $0.lastNALTypes = nalTypeInts
            if isHevc {
                $0.vpsNALs += nalTypeInts.filter { $0 == 32 }.count
                $0.spsNALs += nalTypeInts.filter { $0 == 33 }.count
                $0.ppsNALs += nalTypeInts.filter { $0 == 34 }.count
            } else {
                $0.spsNALs += nalTypeInts.filter { $0 == 7 }.count
                $0.ppsNALs += nalTypeInts.filter { $0 == 8 }.count
            }
            if isKeyframe {
                $0.idrFrames += 1
            }
        }

        var paramSetsChanged = false
        if let v = extractedVPS, v != self.vps {
            self.vps = v
            paramSetsChanged = true
        }
        if let s = extractedSPS, s != self.sps {
            self.sps = s
            paramSetsChanged = true
        }
        if let p = extractedPPS, p != self.pps {
            self.pps = p
            paramSetsChanged = true
        }

        if formatDescription == nil || paramSetsChanged {
            if isHevc, let v = vps, let s = sps, let p = pps {
                if let desc = createHevcFormatDescription(vps: v, sps: s, pps: p) {
                    formatDescription = desc
                    updateDiagnostics { $0.formatDescriptions += 1 }
                } else {
                    updateDiagnostics { $0.formatFailures += 1 }
                    recordDecodeFailure(reason: "HEVC format description creation failed")
                }
            } else if !isHevc, let s = sps, let p = pps {
                if let desc = createH264FormatDescription(sps: s, pps: p) {
                    formatDescription = desc
                    updateDiagnostics { $0.formatDescriptions += 1 }
                } else {
                    updateDiagnostics { $0.formatFailures += 1 }
                    recordDecodeFailure(reason: "H.264 format description creation failed")
                }
            }
        }

        if let formatDesc = formatDescription, paramSetsChanged {
            let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
            if dims.width > 0 && dims.height > 0 {
                let resolved = CGSize(width: Int(dims.width), height: Int(dims.height))
                if resolved != lastNotifiedVideoSize {
                    lastNotifiedVideoSize = resolved
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.onVideoSizeResolved?(resolved)
                        self.applyGeometry()
                    }
                }
            }
        }

        guard let formatDesc = formatDescription else {
            var drops = 0
            updateDiagnostics {
                $0.missingConfigDrops += 1
                drops = $0.missingConfigDrops
            }
            if drops == 1 || drops % 30 == 0 {
                onKeyframeRequested?()
            }
            return
        }

        guard hasVclSlice, !accessUnitNALs.isEmpty else {
            return
        }

        if !hasDecodedKeyframe {
            guard isKeyframe else {
                var drops = 0
                updateDiagnostics {
                    $0.awaitingIDRDrops += 1
                    drops = $0.awaitingIDRDrops
                }
                if drops == 1 || drops % 30 == 0 {
                    onKeyframeRequested?()
                }
                return
            }
        }

        if isKeyframe {
            keyframeRepairTracker.onKeyframeFed(ptsUs: frameIndex)
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let repairConfirmed = isKeyframe && keyframeRepairTracker.keyframeDecoded
        let outcome = CorruptionConcealmentPolicy.next(
            nowMs: nowMs,
            state: concealmentState,
            windowOpenedMs: concealmentWindowOpenedMs,
            corruptionReported: false,
            keyframeRepaired: repairConfirmed,
            sessionHasRendered: sessionHasRendered
        )

        switch outcome {
        case .closeRepaired, .rearm:
            concealmentState = .armed
        case .closeExpired:
            concealmentState = .disarmed
        case .conceal:
            updateDiagnostics { $0.concealedFrames += 1 }
            return
        case .open:
            concealmentState = .concealing
            concealmentWindowOpenedMs = nowMs
            updateDiagnostics { $0.concealedFrames += 1 }
            return
        case .show:
            break
        }

        let lengthSampleData = makeLengthPrefixedSample(from: accessUnitNALs)
        guard !lengthSampleData.isEmpty else { return }
        let parseMs = (ProcessInfo.processInfo.systemUptime - parseStartTime) * 1000.0

        guard let sampleBuffer = makeSampleBuffer(data: lengthSampleData, formatDescription: formatDesc) else {
            updateDiagnostics { $0.sampleFailures += 1 }
            recordDecodeFailure(reason: "CMSampleBuffer creation failed")
            return
        }
        updateDiagnostics { $0.sampleBuffers += 1 }

        let currentPts = frameIndex
        let elapsedUs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1_000_000)
        latencyMonitor.onFrameDecoded(latencyUs: elapsedUs)

        let entry = PacedSampleEntry(
            sampleBuffer: sampleBuffer,
            ptsUs: currentPts,
            isKeyframe: isKeyframe,
            parseMs: parseMs,
            frameBytes: frame.count
        )

        if motionBlurMode == .off {
            submitSampleEntry(entry, displayImmediately: true, doNotDisplay: false)
        } else {
            pacedQueueLock.lock()
            pacedSampleQueue.append(entry)
            pacedQueueLock.unlock()
            ensureDisplayLinkStarted()
        }
    }

    private func configureSampleAttachments(
        _ sampleBuffer: CMSampleBuffer,
        displayImmediately: Bool,
        doNotDisplay: Bool
    ) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: true
        ), CFArrayGetCount(attachments) > 0 else { return }
        let dict = unsafeBitCast(
            CFArrayGetValueAtIndex(attachments, 0),
            to: CFMutableDictionary.self
        )
        CFDictionarySetValue(
            dict,
            Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
            Unmanaged.passUnretained(displayImmediately ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
        )
        CFDictionarySetValue(
            dict,
            Unmanaged.passUnretained(kCMSampleAttachmentKey_DoNotDisplay).toOpaque(),
            Unmanaged.passUnretained(doNotDisplay ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
        )
    }

    private func submitSampleEntry(
        _ entry: PacedSampleEntry,
        displayImmediately: Bool,
        doNotDisplay: Bool
    ) {
        guard !isInBackground else { return }

        configureSampleAttachments(
            entry.sampleBuffer,
            displayImmediately: displayImmediately,
            doNotDisplay: doNotDisplay
        )

        if displayLayer.status == .failed {
            updateDiagnostics { $0.layerFailures += 1 }
            recordDecodeFailure(reason: "AVSampleBufferDisplayLayer status is failed")
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.flushAndRemoveImage()
            }
            formatDescription = nil
            frameIndex = 0
            hasDecodedKeyframe = false
            notReadyStreak = 0
            onKeyframeRequested?()
            return
        }

        var waitCount = 0
        var waitDurationMs = 0.0
        if !displayLayer.isReadyForMoreMediaData {
            let waitStart = ProcessInfo.processInfo.systemUptime
            while !displayLayer.isReadyForMoreMediaData && waitCount < 8 {
                Thread.sleep(forTimeInterval: 0.002)
                waitCount += 1
            }
            waitDurationMs = (ProcessInfo.processInfo.systemUptime - waitStart) * 1000.0
        }

        guard displayLayer.isReadyForMoreMediaData else {
            updateDiagnostics { $0.notReadyDrops += 1 }
            notReadyStreak += 1

            if notReadyStreak == 15 || notReadyStreak >= 90 {
                onKeyframeRequested?()
            }

            if notReadyStreak == 30 {
                DispatchQueue.main.async { [weak self] in
                    self?.displayLayer.flush()
                }
            } else if notReadyStreak >= 90 {
                DispatchQueue.main.async { [weak self] in
                    self?.displayLayer.flushAndRemoveImage()
                }
                formatDescription = nil
                frameIndex = 0
                hasDecodedKeyframe = false
                notReadyStreak = 0
            }
            return
        }

        hasDecodedKeyframe = true
        notReadyStreak = 0
        consecutiveDecodeFailures = 0
        displayLayer.enqueue(entry.sampleBuffer)

        if !doNotDisplay {
            let nowUptime = ProcessInfo.processInfo.systemUptime
            let renderGapMs = lastRenderUptime > 0 ? (nowUptime - lastRenderUptime) * 1000.0 : 0
            lastRenderUptime = nowUptime

            frameQueueLock.lock()
            let pendingQ = pendingFrames.count
            frameQueueLock.unlock()

            let ptsLeadMs = lastCalculatedPtsLeadMs

            if sessionHasRendered {
                if (renderGapMs > 45.0 && renderGapMs < 2000.0) || (entry.parseMs + waitDurationMs > 12.0) {
                    AppLog.category(
                        .videoTelemetry,
                        "[VIDEO-HITCH] frame=#\(decodedFrameCount) renderGap=\(String(format: "%.1f", renderGapMs))ms netGap=\(String(format: "%.1f", renderGapMs))ms bytes=\(entry.frameBytes) isIDR=\(entry.isKeyframe) parseMs=\(String(format: "%.2f", entry.parseMs))ms layerWaitMs=\(String(format: "%.2f", waitDurationMs))ms pendingQ=\(pendingQ) ptsLead=\(String(format: "%.1f", ptsLeadMs))ms",
                        tag: "VideoRenderer"
                    )
                }
            }

            enqueuedFrames1s += 1
            parseDurationMsSum1s += entry.parseMs
            if entry.parseMs > maxParseMs1s { maxParseMs1s = entry.parseMs }
            if waitCount > 0 {
                layerWaitCount1s += 1
                layerWaitDurationMsSum1s += waitDurationMs
            }
            ptsLeadMsSum1s += ptsLeadMs
            if renderGapMs > renderGapMaxMs1s { renderGapMaxMs1s = renderGapMs }
            if pendingQ > qMax1s { qMax1s = pendingQ }

            if lastTelemetryUptime == 0 {
                lastTelemetryUptime = nowUptime
            } else if nowUptime - lastTelemetryUptime >= 1.0 {
                let elapsed = nowUptime - lastTelemetryUptime
                let enqFps = Int((Double(enqueuedFrames1s) / elapsed).rounded())
                let avgParse = enqueuedFrames1s > 0 ? String(format: "%.2f", parseDurationMsSum1s / Double(enqueuedFrames1s)) : "0.00"
                let maxParse = String(format: "%.2f", maxParseMs1s)
                let avgWaitMs = layerWaitCount1s > 0 ? String(format: "%.1f", layerWaitDurationMsSum1s) : "0.0"
                let avgPtsLead = enqueuedFrames1s > 0 ? String(format: "%.1f", ptsLeadMsSum1s / Double(enqueuedFrames1s)) : "0.0"
                let renderGapMax = String(format: "%.1f", renderGapMaxMs1s)

                let netStats = onProvideNetStats?() ?? (fps: 0, bytes: 0, maxGapMs: 0.0)
                let netFps = netStats.fps
                let mbps = String(format: "%.2f", Double(netStats.bytes * 8) / (elapsed * 1_000_000.0))
                let netGap = String(format: "%.1f", netStats.maxGapMs)

                let currentDiag = currentDiagnostics
                let qDrop = currentDiag.queueDrops - lastReportedQDrops
                let nrDrop = currentDiag.notReadyDrops - lastReportedNotReadyDrops
                let idrDrop = currentDiag.awaitingIDRDrops - lastReportedAwaitingIdrDrops
                lastReportedQDrops = currentDiag.queueDrops
                lastReportedNotReadyDrops = currentDiag.notReadyDrops
                lastReportedAwaitingIdrDrops = currentDiag.awaitingIDRDrops

                AppLog.category(
                    .videoTelemetry,
                    "[VIDEO-1S] netRx=\(netFps)fps(\(mbps)Mbps) enq=\(enqFps)fps | netGapMax=\(netGap)ms renderGapMax=\(renderGapMax)ms | parseAvg=\(avgParse)ms(max=\(maxParse)ms) | layerWait=\(layerWaitCount1s)(\(avgWaitMs)ms) | ptsLead=\(avgPtsLead)ms | qMax=\(qMax1s) drops(q=\(qDrop),notReady=\(nrDrop),awaitIDR=\(idrDrop))",
                    tag: "VideoRenderer"
                )

                enqueuedFrames1s = 0
                parseDurationMsSum1s = 0
                maxParseMs1s = 0
                layerWaitCount1s = 0
                layerWaitDurationMsSum1s = 0
                ptsLeadMsSum1s = 0
                renderGapMaxMs1s = 0
                qMax1s = pendingQ
                lastTelemetryUptime = nowUptime
            }

            let nowTime = CACurrentMediaTime()
            fpsFrameCount += 1
            if lastFpsTimestamp == 0 {
                lastFpsTimestamp = nowTime
            } else if nowTime - lastFpsTimestamp >= 1.0 {
                currentFps = Int((Double(fpsFrameCount) / (nowTime - lastFpsTimestamp)).rounded())
                fpsFrameCount = 0
                lastFpsTimestamp = nowTime
            }
            sessionHasRendered = true
            _ = keyframeRepairTracker.onFrameRendered(ptsUs: entry.ptsUs)

            updateDiagnostics { $0.enqueuedSamples += 1 }
            onFrameDisplayed?()
        }
    }

    @objc private func handleVSyncTick(_ link: CADisplayLink) {
        processVSyncTick()
    }

    public func tickVSyncForTesting() {
        processVSyncTick()
    }

    private func processVSyncTick() {
        guard !isInBackground else { return }
        let now = ProcessInfo.processInfo.systemUptime

        var skippedForReference: [PacedSampleEntry] = []
        var chosenToDisplay: PacedSampleEntry?

        pacedQueueLock.lock()
        let count = pacedSampleQueue.count
        if count > 0 {
            let maxHold = motionBlurMode.maxBufferedFrames
            let elapsed = now - lastVSyncPresentUptime
            let is30Fps = (ProjectionSettings.effectiveFpsLimit.rawValue == 2 || ProjectionSettings.effectiveFpsLimit == .fps30)
            let minInterval: TimeInterval = is30Fps ? 0.0285 : 0.0142

            if maxHold > 0 && count > maxHold {
                let dropCount = count - maxHold
                for _ in 0..<dropCount {
                    if !pacedSampleQueue.isEmpty {
                        skippedForReference.append(pacedSampleQueue.removeFirst())
                    }
                }
                if !pacedSampleQueue.isEmpty {
                    chosenToDisplay = pacedSampleQueue.removeFirst()
                    lastVSyncPresentUptime = now
                }
            } else {
                let canPresent: Bool
                if lastVSyncPresentUptime == 0 || elapsed >= minInterval {
                    canPresent = true
                } else if !motionBlurMode.enforcesStrictCadence && motionBlurMode == .light && count == 1 && elapsed >= 0.0075 {
                    canPresent = true
                } else {
                    canPresent = false
                }

                if canPresent && !pacedSampleQueue.isEmpty {
                    chosenToDisplay = pacedSampleQueue.removeFirst()
                    lastVSyncPresentUptime = now
                }
            }
        }
        pacedQueueLock.unlock()

        guard chosenToDisplay != nil || !skippedForReference.isEmpty else { return }

        processQueue.async { [weak self] in
            guard let self = self, !self.isInBackground else { return }
            for skipped in skippedForReference {
                self.submitSampleEntry(skipped, displayImmediately: false, doNotDisplay: true)
            }
            if let displayItem = chosenToDisplay {
                self.submitSampleEntry(displayItem, displayImmediately: true, doNotDisplay: false)
            }
        }
    }

    private func ensureDisplayLinkStarted() {
        guard motionBlurMode != .off, !isInBackground else { return }
        if Thread.isMainThread {
            setupDisplayLinkOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setupDisplayLinkOnMain()
            }
        }
    }

    private func setupDisplayLinkOnMain() {
        guard motionBlurMode != .off, !isInBackground else { return }
        if displayLink == nil {
            let proxy = DisplayLinkTargetProxy(target: self)
            self.displayLinkProxy = proxy
            let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkTargetProxy.onTick(_:)))
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            }
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }
        displayLink?.isPaused = false
    }

    private func pauseDisplayLink() {
        if Thread.isMainThread {
            displayLink?.isPaused = true
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.displayLink?.isPaused = true
            }
        }
    }

    private func resumeDisplayLink() {
        guard motionBlurMode != .off, !isInBackground else { return }
        ensureDisplayLinkStarted()
    }

    private func stopDisplayLink() {
        if Thread.isMainThread {
            displayLink?.invalidate()
            displayLink = nil
            displayLinkProxy = nil
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.displayLink?.invalidate()
                self?.displayLink = nil
                self?.displayLinkProxy = nil
            }
        }
    }

    static func detectHevc(from nalUnits: [Data], preference: VideoCodecPreference = ProjectionSettings.videoCodecPreference) -> Bool {
        for nal in nalUnits {
            guard let b0 = nal.first else { continue }
            let avcType = b0 & 0x1F
            if avcType == 7 || avcType == 8 {
                return false
            }
            if nal.count >= 2 && (b0 & 0x81) == 0 && nal[nal.startIndex + 1] == 0x01 {
                let hevcType = (b0 & 0x7E) >> 1
                if hevcType == 32 || hevcType == 33 || hevcType == 34 {
                    return true
                }
            }
        }
        return preference == .hevc
    }

    private func detectHevc(from nalUnits: [Data]) -> Bool {
        return Self.detectHevc(from: nalUnits, preference: ProjectionSettings.videoCodecPreference)
    }

    private func isEssentialFrame(_ frame: Data) -> Bool {
        let prefix = frame.prefix(256)
        let nalUnits = H264NALParser.nalUnits(from: prefix)
        let isHevc = (pinnedCodec == .hevc)
        for nal in nalUnits {
            guard let first = nal.first else { continue }
            if !isHevc {
                let avcType = first & 0x1F
                if avcType == 5 || avcType == 7 || avcType == 8 {
                    return true
                }
            } else {
                if nal.count >= 2 && (first & 0x81) == 0 && nal[nal.startIndex + 1] == 0x01 {
                    let hevcType = (first & 0x7E) >> 1
                    if hevcType == 32 || hevcType == 33 || hevcType == 34 || (16...21).contains(hevcType) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func createH264FormatDescription(sps: Data, pps: Data) -> CMVideoFormatDescription? {
        return sps.withUnsafeBytes { spsPtr in
            pps.withUnsafeBytes { ppsPtr in
                guard let spsBase = spsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let ppsBase = ppsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return nil
                }
                var formatDesc: CMFormatDescription?
                let parameterSetPointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                let parameterSetSizes: [Int] = [sps.count, pps.count]

                let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: parameterSetPointers,
                    parameterSetSizes: parameterSetSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDesc
                )
                guard status == noErr else { return nil }
                return formatDesc
            }
        }
    }

    private func createHevcFormatDescription(vps: Data, sps: Data, pps: Data) -> CMVideoFormatDescription? {
        return vps.withUnsafeBytes { vpsPtr in
            sps.withUnsafeBytes { spsPtr in
                pps.withUnsafeBytes { ppsPtr in
                    guard let vpsBase = vpsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let spsBase = spsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let ppsBase = ppsPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return nil
                    }
                    var formatDesc: CMFormatDescription?
                    let parameterSetPointers: [UnsafePointer<UInt8>] = [vpsBase, spsBase, ppsBase]
                    let parameterSetSizes: [Int] = [vps.count, sps.count, pps.count]

                    let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: 3,
                        parameterSetPointers: parameterSetPointers,
                        parameterSetSizes: parameterSetSizes,
                        nalUnitHeaderLength: 4,
                        extensions: nil,
                        formatDescriptionOut: &formatDesc
                    )
                    guard status == noErr else { return nil }
                    return formatDesc
                }
            }
        }
    }

    private func makeLengthPrefixedSample(from nalUnits: [Data]) -> Data {
        let totalBytes = nalUnits.reduce(0) { $0 + 4 + $1.count }
        var out = Data()
        out.reserveCapacity(totalBytes)
        for nal in nalUnits {
            guard !nal.isEmpty else { continue }
            var len = UInt32(nal.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(nal)
        }
        return out
    }

    private func makeSampleBuffer(data: Data, formatDescription: CMVideoFormatDescription) -> CMSampleBuffer? {
        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard blockStatus == noErr, let blockBuffer else { return nil }

        let copyStatus = data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
            return CMBlockBufferReplaceDataBytes(
                with: base,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: data.count
            )
        }
        guard copyStatus == noErr else { return nil }

        let nowSeconds = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
        let is30Fps = (ProjectionSettings.effectiveFpsLimit.rawValue == 2 || ProjectionSettings.effectiveFpsLimit == .fps30)
        let frameInterval: Double = is30Fps ? (1.0 / 30.0) : (1.0 / 60.0)
        let targetSeconds = framePacer.nextPts(nowSeconds: nowSeconds, frameInterval: frameInterval)
        var effectivePtsSeconds = targetSeconds
        if effectivePtsSeconds - nowSeconds > frameInterval * 1.2 {
            effectivePtsSeconds = nowSeconds + frameInterval
        }
        lastCalculatedPtsLeadMs = max(0, (effectivePtsSeconds - nowSeconds) * 1000.0)
        let pts = CMTimeMakeWithSeconds(effectivePtsSeconds, preferredTimescale: 1_000_000_000)
        let duration = CMTimeMakeWithSeconds(frameInterval, preferredTimescale: 1_000_000_000)
        var timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        frameIndex += 1

        var sampleBuffer: CMSampleBuffer?
        var sampleSize = data.count
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else { return nil }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: true
        ), CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(
                CFArrayGetValueAtIndex(attachments, 0),
                to: CFMutableDictionary.self
            )
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        decodedFrameCount += 1
        return sampleBuffer
    }

    private func updateDiagnostics(_ update: (inout RendererDiagnostics) -> Void) {
        diagnosticsLock.lock()
        update(&diagnostics)
        diagnosticsLock.unlock()
    }

    private func displayStatusDescription() -> String {
        switch displayLayer.status {
        case .unknown: return "Unknown"
        case .rendering: return "Rendering"
        case .failed: return "Failed"
        @unknown default: return "Other"
        }
    }
}

private final class DisplayLinkTargetProxy: NSObject {
    private weak var target: H264VideoRendererView?

    init(target: H264VideoRendererView) {
        self.target = target
        super.init()
    }

    @objc func onTick(_ link: CADisplayLink) {
        target?.handleVSyncTick(link)
    }
}

