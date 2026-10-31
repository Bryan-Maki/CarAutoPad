import XCTest
import UIKit
import CoreMedia
@testable import CarAutoPad

final class Phase6DiagnosticsAndPolishTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLog.shared.clear()
        AudioDiagnostics.shared.clear()
        ConnectionIssueStore.shared.clearAll()
    }

    override func tearDown() {
        AppLog.shared.clear()
        AudioDiagnostics.shared.clear()
        ConnectionIssueStore.shared.clearAll()
        super.tearDown()
    }

    func testPerformanceOverlayPolicyFormatting() {
        let snapshot = PerformanceSnapshot(
            fps: 60,
            rxMbps: 14.82,
            decodeMedianMs: 3.5,
            decodeP95Ms: 6.2,
            audioBufferMs: 32,
            keyframeRepairs: 2,
            droppedFrames: 1,
            resolutionText: "1920x1080"
        )

        let hudText = PerformanceOverlayPolicy.formatHudText(snapshot)
        XCTAssertTrue(hudText.contains("RES 1920x1080"), "Should include resolution")
        XCTAssertTrue(hudText.contains("60 FPS"), "Should include FPS")
        XCTAssertTrue(hudText.contains("14.8 Mbps"), "Should format rxMbps with 1 decimal place")
        XCTAssertTrue(hudText.contains("DEC 3.5ms (p95 6.2ms)"), "Should format decode latencies")
        XCTAssertTrue(hudText.contains("AUD 32ms"), "Should include audio buffer depth")
        XCTAssertTrue(hudText.contains("PLI 2"), "Should include keyframe repairs")
        XCTAssertTrue(hudText.contains("DROP 1"), "Should include dropped frames")
    }

    func testPerformanceOverlayViewTouchPassthrough() {
        let overlay = PerformanceOverlayView()
        XCTAssertFalse(overlay.isUserInteractionEnabled, "Performance overlay HUD must have isUserInteractionEnabled=false for touch passthrough")
        XCTAssertEqual(overlay.subviews.count, 1)
        guard let label = overlay.subviews.first as? UILabel else {
            XCTFail("HUD should contain a label")
            return
        }
        XCTAssertFalse(label.isUserInteractionEnabled, "HUD label must also be non-interactive")
    }

    func testAudioStreamTesterGenerateSineWavePCMByteCount() {
        let pcm = AudioStreamTester.generateSineWavePCM(
            sampleRate: 48000,
            channelCount: 2,
            frequencyHz: 440.0,
            durationSeconds: 0.1
        )
        XCTAssertEqual(pcm.count, 19200)

        let empty1 = AudioStreamTester.generateSineWavePCM(sampleRate: 0, channelCount: 2, frequencyHz: 440, durationSeconds: 1.0)
        XCTAssertTrue(empty1.isEmpty)
        let empty2 = AudioStreamTester.generateSineWavePCM(sampleRate: 48000, channelCount: 0, frequencyHz: 440, durationSeconds: 1.0)
        XCTAssertTrue(empty2.isEmpty)
        let empty3 = AudioStreamTester.generateSineWavePCM(sampleRate: 48000, channelCount: 2, frequencyHz: 440, durationSeconds: 0.0)
        XCTAssertTrue(empty3.isEmpty)
    }

    func testAudioStreamTesterSamplesEnvelopeAndNonZero() {
        let pcm = AudioStreamTester.generateSineWavePCM(
            sampleRate: 16000,
            channelCount: 1,
            frequencyHz: 1000.0,
            durationSeconds: 0.05,
            rampSeconds: 0.01
        )
        XCTAssertEqual(pcm.count, Int(16000 * 0.05) * 2)

        let samples: [Int16] = pcm.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int16.self))
        }

        XCTAssertFalse(samples.isEmpty)
        XCTAssertEqual(samples[0], 0)

        let middleIndex = samples.count / 2
        let middleMax = samples[(middleIndex - 10)...(middleIndex + 10)].map { abs(Int($0)) }.max() ?? 0
        XCTAssertGreaterThan(middleMax, 5000, "Synthesized tone must produce significant amplitude in the middle")
    }

    func testAudioDiagnosticsRingBufferLimit() {
        let diag = AudioDiagnostics.shared
        diag.clear()
        XCTAssertEqual(diag.snapshot().count, 0)

        for i in 1...70 {
            diag.record("Event #\(i)")
        }

        let snap = diag.snapshot()
        XCTAssertEqual(snap.count, 64, "AudioDiagnostics should cap at 64 entries in its ring buffer")
        XCTAssertTrue(snap.first?.contains("Event #7") ?? false, "Earliest events (1-6) should have rotated out")
        XCTAssertTrue(snap.last?.contains("Event #70") ?? false, "Latest event should be preserved")
    }

    func testConnectionIssueProperties() {
        for issue in ConnectionIssue.allCases {
            XCTAssertFalse(issue.title.isEmpty, "Every issue must have a non-empty title")
            XCTAssertFalse(issue.resolutionAdvice.isEmpty, "Every issue must provide actionable advice")
        }

        XCTAssertEqual(ConnectionIssue.noDeviceDiscovered.title, "No Device Found on Network")
        XCTAssertTrue(ConnectionIssue.noDeviceDiscovered.resolutionAdvice.contains("port 5277"))

        XCTAssertEqual(ConnectionIssue.headunitServerStuckAfterRetries.title, "Connection Failed After 3 Retries (Server May Be Stuck)")
        XCTAssertTrue(ConnectionIssue.headunitServerStuckAfterRetries.resolutionAdvice.contains("Stop head unit server, then Start head unit server"))

        XCTAssertEqual(ConnectionIssue.wifiRadioOff.title, "Search Failed: No Wi-Fi / Hotspot")
        XCTAssertTrue(ConnectionIssue.wifiRadioOff.resolutionAdvice.contains("personal hotspot"))
    }

    func testConnectionIssueStorePersistenceAndClear() {
        let store = ConnectionIssueStore.shared
        store.clearAll()
        XCTAssertEqual(store.currentIssues().count, 0)

        store.raise(issue: .connectionRefused5277, epochMs: 1000)
        XCTAssertEqual(store.currentIssues().count, 1)
        XCTAssertEqual(store.currentIssues().first?.issue, .connectionRefused5277)

        store.raise(issue: .connectionRefused5277, epochMs: 2000)
        XCTAssertEqual(store.currentIssues().count, 1)
        XCTAssertEqual(store.currentIssues().first?.raisedAtEpochMs, 2000)

        store.raise(issue: .tlsHandshakeFailed, epochMs: 3000)
        XCTAssertEqual(store.currentIssues().count, 2)

        store.clear(issue: .connectionRefused5277)
        XCTAssertEqual(store.currentIssues().count, 1)
        XCTAssertEqual(store.currentIssues().first?.issue, .tlsHandshakeFailed)

        store.clearAll()
        XCTAssertEqual(store.currentIssues().count, 0)
    }

    func testConnectionIssueBannerPolicy() {
        let issue1 = StandingIssue(issue: .headunitServerNotAnswering, raisedAtEpochMs: 1000)
        let issue2 = StandingIssue(issue: .connectionRefused5277, raisedAtEpochMs: 2000)

        let bannerConnected = ConnectionIssueBannerPolicy.bannerFor(
            standing: [issue1, issue2],
            sessionConnected: true,
            dismissedAtEpochMs: nil
        )
        XCTAssertNil(bannerConnected, "Banner must be suppressed when projection session is connected")

        let bannerDisconnected = ConnectionIssueBannerPolicy.bannerFor(
            standing: [issue1, issue2],
            sessionConnected: false,
            dismissedAtEpochMs: nil
        )
        XCTAssertEqual(bannerDisconnected?.issue, .connectionRefused5277)

        let bannerDismissed = ConnectionIssueBannerPolicy.bannerFor(
            standing: [issue1, issue2],
            sessionConnected: false,
            dismissedAtEpochMs: 2000
        )
        XCTAssertNil(bannerDismissed, "Issues <= dismissed epoch must be suppressed")

        let issue3 = StandingIssue(issue: .wifiRadioOff, raisedAtEpochMs: 2500)
        let bannerNew = ConnectionIssueBannerPolicy.bannerFor(
            standing: [issue1, issue2, issue3],
            sessionConnected: false,
            dismissedAtEpochMs: 2000
        )
        XCTAssertEqual(bannerNew?.issue, .wifiRadioOff)

        let issue4 = StandingIssue(issue: .noDeviceDiscovered, raisedAtEpochMs: 3000)
        let issue5 = StandingIssue(issue: .headunitServerStuckAfterRetries, raisedAtEpochMs: 4000)
        let bannerStuck = ConnectionIssueBannerPolicy.bannerFor(
            standing: [issue1, issue2, issue3, issue4, issue5],
            sessionConnected: false,
            dismissedAtEpochMs: nil
        )
        XCTAssertEqual(bannerStuck?.issue, .headunitServerStuckAfterRetries)
    }

    func testAppLogInMemBufferAndClear() {
        AppLog.shared.clear()
        XCTAssertEqual(AppLog.shared.recentLogs().count, 0)

        AppLog.d("Debug message", tag: "Test")
        AppLog.i("Info message", tag: "Test")
        AppLog.w("Warning message", tag: "Test")
        AppLog.e("Error message", tag: "Test")

        let logs = AppLog.shared.recentLogs()
        XCTAssertEqual(logs.count, 4)
        XCTAssertTrue(logs[0].contains("[DEBUG] [Test] Debug message"))
        XCTAssertTrue(logs[1].contains("[INFO] [Test] Info message"))
        XCTAssertTrue(logs[2].contains("[WARN] [Test] Warning message"))
        XCTAssertTrue(logs[3].contains("[ERROR] [Test] Error message"))

        AppLog.shared.clear()
        XCTAssertEqual(AppLog.shared.recentLogs().count, 0)
    }

    func testLogExporterBannerAndReport() {
        let banner = LogExporter.sessionBanner()
        XCTAssertTrue(banner.contains("=== CARAUTOPAD DIAGNOSTICS REPORT ==="))
        XCTAssertTrue(banner.contains("Connection State:"))
        XCTAssertTrue(banner.contains("Video Codec:"))

        let fullReport = LogExporter.generateFullReport()
        XCTAssertTrue(fullReport.contains("AUDIO DIAGNOSTICS"))
        XCTAssertTrue(fullReport.contains("APPLICATION LOGS"))
    }

    func testLogExporterClipboardLimitAndFileExport() {
        let url = LogExporter.exportToTemporaryFile()
        XCTAssertNotNil(url)
        if let url = url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            try? FileManager.default.removeItem(at: url)
        }

        let clipboard = LogExporter.exportToClipboardText(maxBytes: 500)
        XCTAssertLessThanOrEqual(clipboard.utf8.count, 500)
    }

    func testSettingsBackupManagerExportAndImport() throws {
        let json = SettingsBackupManager.exportToJson()
        XCTAssertTrue(json.contains("\"format\" : \"carautopad-settings\""))
        XCTAssertTrue(json.contains("\"version\" : 1"))

        ProjectionSettings.dpi = 222
        ProjectionSettings.autoReconnect = false

        let count = try SettingsBackupManager.importFromJson(json)
        XCTAssertEqual(count, 14)

        XCTAssertThrowsError(try SettingsBackupManager.importFromJson("not json")) { error in
            guard case SettingsBackupError.corruptedData = error else {
                XCTFail("Expected corruptedData error")
                return
            }
        }

        let validContainerJson = SettingsBackupManager.exportToJson()
        let wrongFormat = validContainerJson.replacingOccurrences(of: "\"format\" : \"carautopad-settings\"", with: "\"format\" : \"wrong-format\"")
        XCTAssertThrowsError(try SettingsBackupManager.importFromJson(wrongFormat)) { error in
            guard case SettingsBackupError.invalidFormat = error else {
                XCTFail("Expected invalidFormat error, got: \(error)")
                return
            }
        }

        let wrongVersion = validContainerJson.replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99")
        XCTAssertThrowsError(try SettingsBackupManager.importFromJson(wrongVersion)) { error in
            guard case SettingsBackupError.unsupportedVersion(let v) = error, v == 99 else {
                XCTFail("Expected unsupportedVersion(99) error, got: \(error)")
                return
            }
        }

        SettingsBackupManager.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.dpi, ProjectionSettings.defaultDpi)
        XCTAssertTrue(ProjectionSettings.autoReconnect)
        XCTAssertEqual(ProjectionSettings.fitMode, .fillMargin)
        XCTAssertEqual(ProjectionSettings.gpsSource, .phone)
    }

    func testAnnouncedDensityPolicyHuigMaxDpiSymmetry() {
        let landscapeMax = AnnouncedDensityPolicy.huigMaxDpi(w: 1920, h: 1080)
        let portraitMax = AnnouncedDensityPolicy.huigMaxDpi(w: 1080, h: 1920)
        XCTAssertEqual(landscapeMax, portraitMax, "huigMaxDpi must yield identical results regardless of landscape vs portrait orientation")
        XCTAssertGreaterThan(landscapeMax, 160)
    }

    func testAnnouncedDensityPolicyTierSelectionShortSide() {
        let dpiLandscape = AnnouncedDensityPolicy.recommendedDpi(activeW: 1920, activeH: 1080, panelW: 2360, panelH: 1640)
        let dpiPortrait = AnnouncedDensityPolicy.recommendedDpi(activeW: 1080, activeH: 1920, panelW: 1640, panelH: 2360)
        XCTAssertEqual(dpiLandscape, dpiPortrait, "Recommended DPI must match between landscape and portrait for the same panel aspect")
    }

    private final class MockByteConnection: ByteStreamConnection {
        weak var delegate: ByteStreamConnectionDelegate?
        var isConnected: Bool = true
        var sentPackets: [Data] = []
        func send(_ data: Data, completion: ((Error?) -> Void)?) {
            sentPackets.append(data)
            completion?(nil)
        }
        func disconnect() { isConnected = false }
    }

    func testAapTransportTimingDefaults() {
        let mockStream = MockByteConnection()
        let transport = AapTransport(connection: mockStream)

        XCTAssertEqual(transport.initialVersionRequestDelay, 0.5, accuracy: 0.001, "initialVersionRequestDelay must be 0.5s for stable handshake")
        XCTAssertEqual(transport.versionRetryInterval, 2.0, accuracy: 0.001, "versionRetryInterval must be 2.0s")
        XCTAssertEqual(transport.currentRxMbps, 0.0, "Initial Rx throughput must be 0.0 Mbps")
    }

    func testDebugLogCategoryCasesAndDefaults() {
        XCTAssertEqual(DebugLogCategory.allCases.count, 5)
        XCTAssertEqual(DebugLogCategory.connectionHandshake.rawValue, "CONN")
        XCTAssertEqual(DebugLogCategory.videoTelemetry.rawValue, "VIDEO")
        XCTAssertEqual(DebugLogCategory.touchLatency.rawValue, "TOUCH")
        XCTAssertEqual(DebugLogCategory.protocolControl.rawValue, "PROTO")
        XCTAssertEqual(DebugLogCategory.audioMic.rawValue, "AUDIO")

        XCTAssertTrue(DebugLogCategory.connectionHandshake.defaultEnabled)
        XCTAssertTrue(DebugLogCategory.videoTelemetry.defaultEnabled)
        XCTAssertTrue(DebugLogCategory.touchLatency.defaultEnabled)
        XCTAssertTrue(DebugLogCategory.protocolControl.defaultEnabled)
        XCTAssertFalse(DebugLogCategory.audioMic.defaultEnabled)
    }

    func testDebugLogCategoryPersistenceAndFiltering() {
        AppLog.shared.clear()

        ProjectionSettings.setDebugCategory(.audioMic, enabled: false)
        XCTAssertFalse(ProjectionSettings.isDebugCategoryEnabled(.audioMic))

        AppLog.category(.audioMic, "Hidden audio message")
        XCTAssertFalse(AppLog.shared.allLogText().contains("Hidden audio message"))

        ProjectionSettings.setDebugCategory(.audioMic, enabled: true)
        XCTAssertTrue(ProjectionSettings.isDebugCategoryEnabled(.audioMic))

        AppLog.category(.audioMic, "Visible audio message")
        XCTAssertTrue(AppLog.shared.allLogText().contains("Visible audio message"))

        ProjectionSettings.enableAllDebugCategories()
        for cat in DebugLogCategory.allCases {
            XCTAssertTrue(ProjectionSettings.isDebugCategoryEnabled(cat))
        }

        AppLog.shared.clear()
        XCTAssertEqual(AppLog.shared.recentLogs().count, 0)
    }

    func testVideoRendererBackgroundForegroundLifecycle() {
        let renderer = H264VideoRendererView()
        XCTAssertFalse(renderer.isInBackground)

        renderer.enterBackground()
        XCTAssertTrue(renderer.isInBackground)

        let dummyFrame = Data([0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x1f])
        renderer.enqueueAnnexBFrame(dummyFrame)
        XCTAssertEqual(renderer.currentDiagnostics.inputFrames, 0)

        renderer.enterForeground()
        XCTAssertFalse(renderer.isInBackground)
        XCTAssertNil(renderer.displayLayer.controlTimebase)

        renderer.enterBackground()
        XCTAssertTrue(renderer.isInBackground)
        renderer.reset()
        XCTAssertFalse(renderer.isInBackground)
    }

    func testMotionBlurModeMetadataAndDefaults() {
        XCTAssertEqual(MotionBlurMode.allCases.count, 4)
        XCTAssertEqual(FrameSmoothingMode.allCases.count, 4)
        XCTAssertEqual(MotionBlurMode.off.rawValue, 0)
        XCTAssertEqual(MotionBlurMode.light.rawValue, 1)
        XCTAssertEqual(MotionBlurMode.medium.rawValue, 2)
        XCTAssertEqual(MotionBlurMode.strong.rawValue, 3)

        XCTAssertEqual(MotionBlurMode.off.title, "Off")
        XCTAssertEqual(MotionBlurMode.light.title, "Subtle (Low-Latency)")
        XCTAssertEqual(MotionBlurMode.medium.title, "Balanced (Smooth)")
        XCTAssertEqual(MotionBlurMode.strong.title, "Strong (Max Pacing)")

        XCTAssertEqual(MotionBlurMode.off.shortTitle, "Off")
        XCTAssertEqual(MotionBlurMode.light.shortTitle, "Subtle")
        XCTAssertEqual(MotionBlurMode.medium.shortTitle, "Balanced")
        XCTAssertEqual(MotionBlurMode.strong.shortTitle, "Strong")

        XCTAssertEqual(MotionBlurMode.off.maxBufferedFrames, 0)
        XCTAssertEqual(MotionBlurMode.light.maxBufferedFrames, 2)
        XCTAssertEqual(MotionBlurMode.medium.maxBufferedFrames, 3)
        XCTAssertEqual(MotionBlurMode.strong.maxBufferedFrames, 4)

        XCTAssertFalse(MotionBlurMode.off.enforcesStrictCadence)
        XCTAssertFalse(MotionBlurMode.light.enforcesStrictCadence)
        XCTAssertTrue(MotionBlurMode.medium.enforcesStrictCadence)
        XCTAssertTrue(MotionBlurMode.strong.enforcesStrictCadence)

        XCTAssertEqual(MotionBlurMode.off.trailOpacity, 0.0)
        XCTAssertEqual(MotionBlurMode.light.trailOpacity, 0.18, accuracy: 0.001)
        XCTAssertEqual(MotionBlurMode.medium.trailOpacity, 0.32, accuracy: 0.001)
        XCTAssertEqual(MotionBlurMode.strong.trailOpacity, 0.48, accuracy: 0.001)
    }

    func testMotionBlurModePersistenceAndReset() {
        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.motionBlurMode, .off)

        ProjectionSettings.motionBlurMode = .medium
        XCTAssertEqual(ProjectionSettings.motionBlurMode, .medium)

        ProjectionSettings.motionBlurMode = .strong
        XCTAssertEqual(ProjectionSettings.motionBlurMode, .strong)

        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.motionBlurMode, .off)
    }

    func testSettingsBackupManagerMotionBlurModeExportAndImport() throws {
        ProjectionSettings.resetToDefaults()
        ProjectionSettings.motionBlurMode = .strong

        let json = SettingsBackupManager.exportToJson()
        XCTAssertTrue(json.contains("\"motionBlurMode\" : 3"))

        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.motionBlurMode, .off)

        let count = try SettingsBackupManager.importFromJson(json)
        XCTAssertEqual(count, 14)
        XCTAssertEqual(ProjectionSettings.motionBlurMode, .strong)
    }

    func testVideoRendererFrameSmoothingHotSwitchingAndQueueLifecycle() {
        ProjectionSettings.resetToDefaults()
        let renderer = H264VideoRendererView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(renderer.motionBlurMode, .off)
        XCTAssertEqual(renderer.queuedPacedSampleCount, 0)
        XCTAssertFalse(renderer.isDisplayLinkActive)

        var keyframeRequested = false
        renderer.onKeyframeRequested = {
            keyframeRequested = true
        }

        renderer.motionBlurMode = .light
        XCTAssertEqual(renderer.motionBlurMode, .light)

        let exp = expectation(description: "Frame smoothing mode change processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(renderer.isDisplayLinkActive)
            XCTAssertTrue(keyframeRequested, "Switching frame smoothing mode on should request keyframe")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        // Test backgrounding cleans queue and pauses display link
        renderer.enterBackground()
        XCTAssertTrue(renderer.isInBackground)
        XCTAssertEqual(renderer.queuedPacedSampleCount, 0)
        XCTAssertFalse(renderer.isDisplayLinkActive)

        // Test foregrounding restores display link
        renderer.enterForeground()
        XCTAssertFalse(renderer.isInBackground)
        let expForeground = expectation(description: "DisplayLink restored on foreground")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(renderer.isDisplayLinkActive)
            expForeground.fulfill()
        }
        wait(for: [expForeground], timeout: 1.0)

        // Test switching off stops display link and clears queue
        renderer.motionBlurMode = .off
        XCTAssertEqual(renderer.motionBlurMode, .off)
        let exp2 = expectation(description: "Frame smoothing mode off processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(renderer.isDisplayLinkActive)
            XCTAssertEqual(renderer.queuedPacedSampleCount, 0)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)
    }

    private func makeTestSampleBuffer() -> CMSampleBuffer? {
        var formatDesc: CMVideoFormatDescription?
        let fmtStatus = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_H264,
            width: 64,
            height: 64,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )
        guard fmtStatus == noErr, let formatDesc = formatDesc else { return nil }

        var blockBuffer: CMBlockBuffer?
        let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x01, 0x65, 0x88, 0x84, 0x00]
        let bbStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: bytes.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: bytes.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard bbStatus == noErr, let blockBuffer = blockBuffer else { return nil }

        let replaceStatus = bytes.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: bytes.count)
        }
        guard replaceStatus == noErr else { return nil }

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: 1, timescale: 60),
            presentationTimeStamp: CMTimeMake(value: 1, timescale: 60),
            decodeTimeStamp: .invalid
        )
        var size = bytes.count
        let sbStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &size,
            sampleBufferOut: &sampleBuffer
        )
        guard sbStatus == noErr else { return nil }
        return sampleBuffer
    }

    func testConfigureSampleAttachmentsImmediatelyAndDoNotDisplay() {
        guard let sampleBuffer = makeTestSampleBuffer() else {
            XCTFail("Failed to create test CMSampleBuffer")
            return
        }
        let renderer = H264VideoRendererView()

        // 1. Immediate display attachments
        renderer.configureSampleAttachments(sampleBuffer, displayImmediately: true, doNotDisplay: false)
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false),
              CFArrayGetCount(attachments) > 0 else {
            XCTFail("Missing sample attachments")
            return
        }
        let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self)
        let displayImm = CFDictionaryGetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque())
        let doNotDisp = CFDictionaryGetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DoNotDisplay).toOpaque())
        XCTAssertEqual(unsafeBitCast(displayImm, to: CFBoolean.self), kCFBooleanTrue)
        XCTAssertEqual(unsafeBitCast(doNotDisp, to: CFBoolean.self), kCFBooleanFalse)

        // 2. Decode-only reference update attachments (DoNotDisplay)
        renderer.configureSampleAttachments(sampleBuffer, displayImmediately: false, doNotDisplay: true)
        let displayImm2 = CFDictionaryGetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque())
        let doNotDisp2 = CFDictionaryGetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DoNotDisplay).toOpaque())
        XCTAssertEqual(unsafeBitCast(displayImm2, to: CFBoolean.self), kCFBooleanFalse)
        XCTAssertEqual(unsafeBitCast(doNotDisp2, to: CFBoolean.self), kCFBooleanTrue)
    }

    func testVideoRendererVSyncPacingBurstCatchUpAndCadence() {
        ProjectionSettings.resetToDefaults()
        let renderer = H264VideoRendererView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        renderer.motionBlurMode = .light // maxBufferedFrames = 2

        guard let sb1 = makeTestSampleBuffer(),
              let sb2 = makeTestSampleBuffer(),
              let sb3 = makeTestSampleBuffer(),
              let sb4 = makeTestSampleBuffer(),
              let sb5 = makeTestSampleBuffer() else {
            XCTFail("Failed to create test sample buffers")
            return
        }

        // Simulate burst arriving with 5 frames:
        renderer.enqueueSampleBufferForTesting(sb1, ptsUs: 1)
        renderer.enqueueSampleBufferForTesting(sb2, ptsUs: 2)
        renderer.enqueueSampleBufferForTesting(sb3, ptsUs: 3)
        renderer.enqueueSampleBufferForTesting(sb4, ptsUs: 4)
        renderer.enqueueSampleBufferForTesting(sb5, ptsUs: 5)

        XCTAssertEqual(renderer.queuedPacedSampleCount, 5)

        // VSync tick with burst backlog (5 > maxHold 2):
        // Excess dropCount = 5 - 2 = 3 frames (sb1, sb2, sb3) dropped for reference (DoNotDisplay = true)
        // Next frame sb4 popped for display, leaving 1 frame (sb5) in queue.
        renderer.tickVSyncForTesting()
        XCTAssertEqual(renderer.queuedPacedSampleCount, 1)

        // Switching to .off drains queue:
        renderer.motionBlurMode = .off
        XCTAssertEqual(renderer.queuedPacedSampleCount, 0)

        // Enqueuing in .off mode bypasses pacing queue:
        guard let sb6 = makeTestSampleBuffer() else { return }
        renderer.enqueueSampleBufferForTesting(sb6, ptsUs: 6)
        XCTAssertEqual(renderer.queuedPacedSampleCount, 0)
    }

    func testEffectiveFpsLimitPortraitModeAndMotionBlurTiming() {
        ProjectionSettings.resetToDefaults()
        ProjectionSettings.fpsLimit = .fps60
        ProjectionSettings.orientation = .portrait
        XCTAssertEqual(ProjectionSettings.effectiveFpsLimit, .fps30, "Portrait orientation must constrain effectiveFpsLimit to 30 FPS")

        let is30Fps = (ProjectionSettings.effectiveFpsLimit.rawValue == 2 || ProjectionSettings.effectiveFpsLimit == .fps30)
        XCTAssertTrue(is30Fps)
        let fps = is30Fps ? 30.0 : 60.0
        XCTAssertEqual(fps, 30.0)
        let frameInterval = 1.0 / fps
        let settleDelay = 1.6 * frameInterval
        XCTAssertEqual(settleDelay, 1.6 * (1.0 / 30.0), accuracy: 0.0001)

        ProjectionSettings.orientation = .landscape
        XCTAssertEqual(ProjectionSettings.effectiveFpsLimit, .fps60)
        let is30FpsLandscape = (ProjectionSettings.effectiveFpsLimit.rawValue == 2 || ProjectionSettings.effectiveFpsLimit == .fps30)
        XCTAssertFalse(is30FpsLandscape)
        let fpsLandscape = is30FpsLandscape ? 30.0 : 60.0
        XCTAssertEqual(fpsLandscape, 60.0)
    }

    func testAapTransportDropsUnencryptedMessageDuringHandshake() {
        final class HandshakeDummyConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            var sentData: [Data] = []
            func send(_ data: Data, completion: ((Error?) -> Void)?) {
                sentData.append(data)
                completion?(nil)
            }
            func disconnect() { isConnected = false }
        }

        let connection = HandshakeDummyConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)
        transport.setState(.waitingForVersion)

        let msg = AapMessage(channel: Channel.ID_SEN, flags: 0, type: 0x8003, payload: Data([0x01]))
        var droppedError: Error?
        transport.send(message: msg) { error in
            droppedError = error
        }

        XCTAssertTrue(connection.sentData.isEmpty, "No plaintext business message should be sent during handshake")
        XCTAssertEqual(droppedError as? AapTransportError, AapTransportError.invalidState)
    }

    func testAapTransportIgnoresLateVersionResponseInTlsHandshake() {
        final class LateVersionDummyConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            func send(_ data: Data, completion: ((Error?) -> Void)?) { completion?(nil) }
            func disconnect() { isConnected = false }
        }

        let connection = LateVersionDummyConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)
        transport.setState(.tlsHandshaking)

        let versionPayload = Data([0x00, 0x01, 0x00, 0x02, 0x00, 0x00])
        let msg = AapMessage(channel: Channel.ID_CTR, flags: 0x03, type: AapMessageType.VERSION_RESPONSE.rawValue, payload: versionPayload)

        transport.handleMessage(msg)
        XCTAssertEqual(transport.state, .tlsHandshaking, "Late VERSION_RESPONSE in .tlsHandshaking must be ignored and not reset state or TLS session")
    }

    func testFrameSmoothingKeyframeImmediateRenderAndZeroAwaitingIDRDrops() {
        ProjectionSettings.resetToDefaults()
        let renderer = H264VideoRendererView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        renderer.motionBlurMode = .medium // Balanced Frame Smoothing mode

        let startCode = Data([0x00, 0x00, 0x00, 0x01])
        let sps = Data([
            0x67, 0x42, 0xc0, 0x1f, 0x8c, 0x8d, 0x40, 0x50,
            0x17, 0xfc, 0xb8, 0x08, 0x80, 0x00, 0x00, 0x03,
            0x00, 0x80, 0x00, 0x00, 0x1e, 0x07, 0x8c, 0x18, 0x80
        ])
        let pps = Data([0x68, 0xce, 0x3c, 0x80])
        let idrSlice = Data([0x65, 0x88, 0x84, 0x00, 0x10, 0x20])
        let idrFrame = startCode + sps + startCode + pps + startCode + idrSlice

        let pSlice = Data([0x41, 0x9a, 0x00, 0x01, 0x10, 0x20])
        let pFrame = startCode + pSlice

        var displayedFrames = 0
        renderer.onFrameDisplayed = {
            displayedFrames += 1
        }

        // 1. Enqueue IDR keyframe
        renderer.enqueueAnnexBFrame(idrFrame)

        // 2. Continuously enqueue 5 P-frames
        for _ in 0..<5 {
            renderer.enqueueAnnexBFrame(pFrame)
        }

        let exp = expectation(description: "Process queued frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let diag = renderer.currentDiagnostics
            XCTAssertEqual(diag.awaitingIDRDrops, 0, "No P-frames should be dropped awaiting IDR when frame smoothing is active")
            XCTAssertEqual(diag.sampleBuffers, 6, "All 6 frames (1 IDR + 5 P-frames) must generate sample buffers without awaitingIDRDrops")
            XCTAssertEqual(diag.queueDrops, 0, "No frames should be dropped from queue")
            XCTAssertGreaterThanOrEqual(diag.enqueuedSamples, 1, "First frame (!sessionHasRendered) must immediately light up screen and increment enqueuedSamples")
            XCTAssertGreaterThanOrEqual(displayedFrames, 1, "First IDR frame must immediately trigger onFrameDisplayed")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testFrameSmoothingKeyframeFlushesStalePacedEntries() {
        ProjectionSettings.resetToDefaults()
        let renderer = H264VideoRendererView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        renderer.motionBlurMode = .medium

        guard let sb1 = makeTestSampleBuffer(),
              let sb2 = makeTestSampleBuffer(),
              let sbKey = makeTestSampleBuffer() else {
            XCTFail("Failed to create test sample buffers")
            return
        }

        // Buffer frames in pacing queue
        renderer.enqueueSampleBufferForTesting(sb1, ptsUs: 1, isKeyframe: false)
        renderer.enqueueSampleBufferForTesting(sb2, ptsUs: 2, isKeyframe: false)
        XCTAssertEqual(renderer.queuedPacedSampleCount, 2)

        // When keyframe arrives, stale queued entries must be flushed and submitted immediately
        renderer.enqueueSampleBufferForTesting(sbKey, ptsUs: 3, isKeyframe: true)
        // Paced queue now contains only the new keyframe
        XCTAssertEqual(renderer.queuedPacedSampleCount, 1)

        // Reset clears pacing queue completely
        renderer.reset()
        XCTAssertEqual(renderer.queuedPacedSampleCount, 0)
    }
}

