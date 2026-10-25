import XCTest
@testable import CarAutoPad

final class Phase3VideoAndRecoveryTests: XCTestCase {

    func testKeyframeRepairTrackerFlow() {
        let tracker = KeyframeRepairTracker()
        XCTAssertFalse(tracker.awaitingOutput)
        XCTAssertFalse(tracker.keyframeDecoded)

        tracker.onKeyframeFed(ptsUs: 1000)
        XCTAssertTrue(tracker.awaitingOutput)

        let r1 = tracker.onFrameRendered(ptsUs: 900)
        XCTAssertFalse(r1)
        XCTAssertTrue(tracker.awaitingOutput)

        let r2 = tracker.onFrameRendered(ptsUs: 1000)
        XCTAssertTrue(r2)
        XCTAssertFalse(tracker.awaitingOutput)
        XCTAssertTrue(tracker.keyframeDecoded)

        XCTAssertFalse(tracker.onFrameRendered(ptsUs: 1033))
    }

    func testKeyframeRepairTrackerTimestampsUnusableFallback() {
        let tracker = KeyframeRepairTracker()
        tracker.onKeyframeFed(ptsUs: 50_000)

        for _ in 0..<29 {
            XCTAssertFalse(tracker.onFrameRendered(ptsUs: 0))
        }
        XCTAssertFalse(tracker.timestampsUnusable)

        let confirmed = tracker.onFrameRendered(ptsUs: 0)
        XCTAssertTrue(confirmed)
        XCTAssertTrue(tracker.timestampsUnusable)
        XCTAssertTrue(tracker.keyframeDecoded)
    }

    func testCorruptionConcealmentStateTransitions() {
        var state = CorruptionConcealmentPolicy.State.armed
        var windowOpenedMs: Int64 = 0

        let o1 = CorruptionConcealmentPolicy.next(
            nowMs: 1000,
            state: state,
            windowOpenedMs: windowOpenedMs,
            corruptionReported: false,
            keyframeRepaired: false,
            sessionHasRendered: true
        )
        XCTAssertEqual(o1, .show)
        XCTAssertTrue(o1.renders)

        let o2 = CorruptionConcealmentPolicy.next(
            nowMs: 1100,
            state: state,
            windowOpenedMs: windowOpenedMs,
            corruptionReported: true,
            keyframeRepaired: false,
            sessionHasRendered: true
        )
        XCTAssertEqual(o2, .open)
        XCTAssertFalse(o2.renders)
        state = .concealing
        windowOpenedMs = 1100

        let o3 = CorruptionConcealmentPolicy.next(
            nowMs: 1200,
            state: state,
            windowOpenedMs: windowOpenedMs,
            corruptionReported: false,
            keyframeRepaired: false,
            sessionHasRendered: true
        )
        XCTAssertEqual(o3, .conceal)
        XCTAssertFalse(o3.renders)

        let o4 = CorruptionConcealmentPolicy.next(
            nowMs: 1300,
            state: state,
            windowOpenedMs: windowOpenedMs,
            corruptionReported: false,
            keyframeRepaired: true,
            sessionHasRendered: true
        )
        XCTAssertEqual(o4, .closeRepaired)
        XCTAssertTrue(o4.renders)
        state = .armed

        state = .concealing
        windowOpenedMs = 2000
        let o5 = CorruptionConcealmentPolicy.next(
            nowMs: 4050,
            state: state,
            windowOpenedMs: windowOpenedMs,
            corruptionReported: false,
            keyframeRepaired: false,
            sessionHasRendered: true
        )
        XCTAssertEqual(o5, .closeExpired)
        XCTAssertTrue(o5.renders)
    }

    func testKeyframeCycleEscalationDecisions() {
        let a1 = KeyframeCycleEscalationPolicy.decide(
            nowMs: 2000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 0,
            lastCycleMs: 0,
            lastWireCorruptionMs: 0
        )
        XCTAssertEqual(a1, .nudge)

        let a2 = KeyframeCycleEscalationPolicy.decide(
            nowMs: 4000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 0,
            lastCycleMs: 0,
            lastWireCorruptionMs: 0
        )
        XCTAssertEqual(a2, .cycleFocus)

        let a3 = KeyframeCycleEscalationPolicy.decide(
            nowMs: 14_000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 1,
            lastCycleMs: 4000,
            lastWireCorruptionMs: 0
        )
        XCTAssertEqual(a3, .nudge)

        let a4 = KeyframeCycleEscalationPolicy.decide(
            nowMs: 40_000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 1,
            lastCycleMs: 4000,
            lastWireCorruptionMs: 39_500
        )
        XCTAssertEqual(a4, .waitForQuiet)

        let a5 = KeyframeCycleEscalationPolicy.decide(
            nowMs: 80_000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 3,
            lastCycleMs: 40_000,
            lastWireCorruptionMs: 0
        )
        XCTAssertEqual(a5, .nudge)
    }

    func testKeyframeCycleRefunds() {
        let refunds = KeyframeCycleEscalationPolicy.cyclesToRefund(
            nowMs: 700_000,
            cyclesUsedThisSession: 2,
            cyclesSpentThisSession: 2,
            lastBudgetChangeMs: 100_000,
            lastWireCorruptionMs: 100_000,
            pictureUnrepaired: false
        )
        XCTAssertEqual(refunds, 2, "Quiet wire should refund spent cycle budget")
    }

    func testWarmRelaunchKeyframeDecisions() {
        let d1 = WarmRelaunchKeyframePolicy.decide(
            sessionHasRendered: true,
            crediblePictureOnSurface: false,
            transportStarted: true,
            msSinceSurfaceSet: 400,
            msSinceLinkActivity: 100,
            linkQuietThresholdMs: 10_000,
            cycleAlreadySpent: false,
            msSinceLastRequest: 5000
        )
        XCTAssertEqual(d1, .none)

        let d2 = WarmRelaunchKeyframePolicy.decide(
            sessionHasRendered: true,
            crediblePictureOnSurface: false,
            transportStarted: true,
            msSinceSurfaceSet: 900,
            msSinceLinkActivity: 100,
            linkQuietThresholdMs: 10_000,
            cycleAlreadySpent: false,
            msSinceLastRequest: 5000
        )
        XCTAssertEqual(d2, .cycleFocus)

        let d3 = WarmRelaunchKeyframePolicy.decide(
            sessionHasRendered: true,
            crediblePictureOnSurface: false,
            transportStarted: true,
            msSinceSurfaceSet: 2000,
            msSinceLinkActivity: 100,
            linkQuietThresholdMs: 10_000,
            cycleAlreadySpent: true,
            msSinceLastRequest: 1500
        )
        XCTAssertEqual(d3, .nudge)

        let d4 = WarmRelaunchKeyframePolicy.decide(
            sessionHasRendered: true,
            crediblePictureOnSurface: true,
            transportStarted: true,
            msSinceSurfaceSet: 2000,
            msSinceLinkActivity: 100,
            linkQuietThresholdMs: 10_000,
            cycleAlreadySpent: false,
            msSinceLastRequest: 5000
        )
        XCTAssertEqual(d4, .none)
    }

    func testVideoFeedQueueCapacity() {
        XCTAssertEqual(VideoFeedQueuePolicy.capacityFor(fpsLimit: 30), 15)

        XCTAssertEqual(VideoFeedQueuePolicy.capacityFor(fpsLimit: 60), 30)

        XCTAssertEqual(VideoFeedQueuePolicy.capacityFor(fpsLimit: 10), 15)
        XCTAssertEqual(VideoFeedQueuePolicy.capacityFor(fpsLimit: 120), 40)
    }

    func testDecodeLatencyMonitorCalculations() {
        let monitor = DecodeLatencyMonitor()

        let latencies: [Int64] = [10_000, 12_000, 15_000, 18_000, 20_000, 25_000, 30_000, 35_000, 40_000, 50_000]
        for lat in latencies {
            monitor.onFrameDecoded(latencyUs: lat)
        }

        guard let report = monitor.report() else {
            XCTFail("Report should not be nil")
            return
        }

        XCTAssertEqual(report.frames, 10)
        XCTAssertEqual(report.unusable, 0)
        XCTAssertTrue(report.medianUs >= 20_000 && report.medianUs <= 25_000)
        XCTAssertTrue(report.p95Us >= 40_000)
    }

    func testVSyncFrameReleasePacerSmoothsBurstArrivals() {
        var pacer = H264VideoRendererView.FrameReleasePacer()
        let frameInterval: Double = 1.0 / 60.0

        let pts0 = pacer.nextPts(nowSeconds: 100.000, frameInterval: frameInterval)
        let pts1 = pacer.nextPts(nowSeconds: 100.001, frameInterval: frameInterval)
        let pts2 = pacer.nextPts(nowSeconds: 100.002, frameInterval: frameInterval)

        XCTAssertEqual(pts0, 100.000, accuracy: 0.0001)
        XCTAssertEqual(pts1, 100.000 + frameInterval, accuracy: 0.0001)
        XCTAssertEqual(pts2, 100.000 + (2.0 * frameInterval), accuracy: 0.0001)

        let gap01 = pts1 - pts0
        let gap12 = pts2 - pts1
        XCTAssertEqual(gap01, frameInterval, accuracy: 0.0001)
        XCTAssertEqual(gap12, frameInterval, accuracy: 0.0001)

        let pts3 = pacer.nextPts(nowSeconds: 100.200, frameInterval: frameInterval)
        XCTAssertEqual(pts3, 100.200, accuracy: 0.0001, "Should catch up to current time when backlog exceeds 2.5 frames")
    }

    func testFrameReleasePacerNeverRegressesPtsDuringRapidArrivals() {
        var pacer = H264VideoRendererView.FrameReleasePacer()
        let frameInterval: Double = 1.0 / 60.0

        var previousPts: Double = -1.0
        for i in 0..<10 {
            let nowSeconds = 50.0 + Double(i) * 0.0005
            let pts = pacer.nextPts(nowSeconds: nowSeconds, frameInterval: frameInterval)
            XCTAssertGreaterThanOrEqual(pts, previousPts, "PTS must be strictly monotonic and never regress")
            previousPts = pts
        }
    }

    func testRendererDropsPFrameWithoutIDRAndRequestsKeyframe() {
        let renderer = H264VideoRendererView()
        let expKeyframe = expectation(description: "Keyframe requested")
        var frameDisplayedCount = 0

        renderer.onKeyframeRequested = {
            expKeyframe.fulfill()
        }
        renderer.onFrameDisplayed = {
            frameDisplayedCount += 1
        }

        // Annex-B P-frame slice NAL (0x41) without SPS/PPS configuration
        let pSlice = Data([0x00, 0x00, 0x00, 0x01, 0x41, 0x9A, 0x00, 0x01])
        renderer.enqueueAnnexBFrame(pSlice)

        wait(for: [expKeyframe], timeout: 2.0)
        XCTAssertEqual(frameDisplayedCount, 0, "P-frame without IDR must never trigger onFrameDisplayed")
        XCTAssertGreaterThan(renderer.currentDiagnostics.missingConfigDrops + renderer.currentDiagnostics.awaitingIDRDrops, 0)
    }

    func testEscalationPolicyAllowsFocusCycleWhenWireIsQuiet() {
        let quietAction = KeyframeCycleEscalationPolicy.decide(
            nowMs: 5000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 0,
            lastCycleMs: 0,
            lastWireCorruptionMs: 0
        )
        XCTAssertEqual(quietAction, .cycleFocus, "Quiet wire must allow escalation to .cycleFocus after unrepaired window")

        let corruptAction = KeyframeCycleEscalationPolicy.decide(
            nowMs: 5000,
            unrepairedSinceMs: 1000,
            cyclesUsedThisSession: 0,
            lastCycleMs: 0,
            lastWireCorruptionMs: 4500
        )
        XCTAssertEqual(corruptAction, .waitForQuiet, "Active wire corruption must wait for quiet")
    }

    func testRendererResetClearsStateCleanly() {
        let renderer = H264VideoRendererView()
        let pSlice = Data([0x00, 0x00, 0x00, 0x01, 0x41, 0x9A, 0x00, 0x01])
        renderer.enqueueAnnexBFrame(pSlice)
        renderer.reset()
        XCTAssertEqual(renderer.currentDiagnostics.inputFrames, 0)
    }
}
