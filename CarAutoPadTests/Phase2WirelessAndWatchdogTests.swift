import XCTest
import UIKit
@testable import CarAutoPad

final class Phase2WirelessAndWatchdogTests: XCTestCase {

    func testDiscoverySubnetPolicyGeneratesHostIps() {
        let baseIp = "192.168.1.50"
        let candidates = DiscoverySubnetPolicy.generateSubnetCandidates(baseIp: baseIp, maxHosts: 5)
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.contains("192.168.1.1"))
    }

    func testSameEndpointConnectPolicy() {
        let policy = SameEndpointConnectPolicy()

        XCTAssertTrue(policy.shouldConnect(endpoint: "192.168.1.100:5277"))
        policy.recordConnectionStarted(endpoint: "192.168.1.100:5277")

        XCTAssertFalse(policy.shouldConnect(endpoint: "192.168.1.100:5277"))

        XCTAssertTrue(policy.shouldConnect(endpoint: "192.168.1.101:5277"))

        policy.recordConnectionEnded(endpoint: "192.168.1.100:5277")
        XCTAssertTrue(policy.shouldConnect(endpoint: "192.168.1.100:5277"))
    }

    func testLinkGapMonitorReportsOutages() {
        let monitor = LinkGapMonitor(minGaps: 1, maxDeadPercent: 10)
        _ = monitor.onMessage(nowMs: 1000)

        let report = monitor.onMessage(nowMs: 4500)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.gaps, 1)
        XCTAssertEqual(report?.longestMs, 3500)
    }

    func testUnresponsivePeerPolicyBackoff() {
        XCTAssertEqual(UnresponsivePeerPolicy.rescanDelayMs(consecutiveSilentFailures: 0), 3_000)
        XCTAssertEqual(UnresponsivePeerPolicy.rescanDelayMs(consecutiveSilentFailures: 2), 3_000)
        XCTAssertEqual(UnresponsivePeerPolicy.rescanDelayMs(consecutiveSilentFailures: 3), 3_000)
        XCTAssertEqual(UnresponsivePeerPolicy.rescanDelayMs(consecutiveSilentFailures: 10), 3_000)

        XCTAssertTrue(UnresponsivePeerPolicy.shouldExplain(consecutiveSilentFailures: 3))
        XCTAssertFalse(UnresponsivePeerPolicy.shouldExplain(consecutiveSilentFailures: 4))

        let count1 = UnresponsivePeerPolicy.countAfterSilentFailure(previousCount: 2, previousEndpoint: "192.168.1.1", endpoint: "192.168.1.1")
        XCTAssertEqual(count1, 3)

        let count2 = UnresponsivePeerPolicy.countAfterSilentFailure(previousCount: 2, previousEndpoint: "192.168.1.1", endpoint: "192.168.1.2")
        XCTAssertEqual(count2, 1)
    }

    func testAutomaticReconnectMaxThreeAttemptsAndThreeSecondDelay() {
        XCTAssertEqual(AutomaticReconnect.defaultMaxAttempts, 3)
        XCTAssertEqual(AutomaticReconnect.defaultRetryDelayMs, 3_000)

        let reconnect = AutomaticReconnect()
        XCTAssertEqual(reconnect.maxAttempts, 3)
        XCTAssertEqual(reconnect.retryDelayMs, 3_000)
        XCTAssertEqual(reconnect.attemptCount, 0)
        XCTAssertFalse(reconnect.isScheduled)
        XCTAssertEqual(reconnect.delaySeconds(forAttempt: 1), 3.0, accuracy: 0.001)
        XCTAssertEqual(reconnect.delaySeconds(forAttempt: 3), 3.0, accuracy: 0.001)

        let dummySession = NSObject()
        reconnect.schedule(endedSession: dummySession, delayMs: 50) {}
        XCTAssertEqual(reconnect.attemptCount, 1)
        XCTAssertTrue(reconnect.isScheduled)

        reconnect.resetAttempts()
        XCTAssertEqual(reconnect.attemptCount, 0)
        XCTAssertFalse(reconnect.isScheduled)
    }

    func testVideoStarvationPolicyStreakAndAdvisory() {
        var streak = 0
        streak = VideoStarvationPolicy.nextStreak(current: streak, reachedHandshake: true, renderedAnyFrame: false)
        XCTAssertEqual(streak, 1)
        XCTAssertFalse(VideoStarvationPolicy.shouldAdvise(consecutiveStarvedSessions: streak))

        streak = VideoStarvationPolicy.nextStreak(current: streak, reachedHandshake: true, renderedAnyFrame: false)
        XCTAssertEqual(streak, 2)
        XCTAssertFalse(VideoStarvationPolicy.shouldAdvise(consecutiveStarvedSessions: streak))

        streak = VideoStarvationPolicy.nextStreak(current: streak, reachedHandshake: true, renderedAnyFrame: false)
        XCTAssertEqual(streak, 3)
        XCTAssertTrue(VideoStarvationPolicy.shouldAdvise(consecutiveStarvedSessions: streak))
        XCTAssertTrue(VideoStarvationPolicy.shouldCap(consecutiveStarvedSessions: streak))

        streak = VideoStarvationPolicy.nextStreak(current: streak, reachedHandshake: true, renderedAnyFrame: true)
        XCTAssertEqual(streak, 0)
        XCTAssertFalse(VideoStarvationPolicy.shouldCap(consecutiveStarvedSessions: streak))
    }

    func testAutoResumePlaybackPolicy() {
        XCTAssertFalse(AutoResumePlaybackPolicy.shouldResume(enabled: false, wasPlayingBeforeDisconnect: true, elapsedSinceDisconnectMs: 5000))

        XCTAssertFalse(AutoResumePlaybackPolicy.shouldResume(enabled: true, wasPlayingBeforeDisconnect: false, elapsedSinceDisconnectMs: 5000))

        XCTAssertTrue(AutoResumePlaybackPolicy.shouldResume(enabled: true, wasPlayingBeforeDisconnect: true, elapsedSinceDisconnectMs: 15000))

        XCTAssertFalse(AutoResumePlaybackPolicy.shouldResume(enabled: true, wasPlayingBeforeDisconnect: true, elapsedSinceDisconnectMs: 65000))
    }

    func testReconnectPlaybackSnapshot() {
        let snapshot = ReconnectPlaybackSnapshot()
        snapshot.onDisconnected(lastPlaying: true, now: 10_000, deliberate: false)

        let resume = snapshot.consume(now: 15_000)
        XCTAssertTrue(resume.wasPlaying)
        XCTAssertEqual(resume.elapsedMs, 5_000)

        let secondConsume = snapshot.consume(now: 20_000)
        XCTAssertFalse(secondConsume.wasPlaying)
    }
}
