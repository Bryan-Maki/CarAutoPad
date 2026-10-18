import Foundation

public enum AutoResumePlaybackPolicy {

    public static let maxReconnectWindowMs: Int64 = 60_000

    public static func shouldResume(
        enabled: Bool,
        wasPlayingBeforeDisconnect: Bool,
        elapsedSinceDisconnectMs: Int64
    ) -> Bool {
        guard enabled else { return false }
        guard wasPlayingBeforeDisconnect else { return false }
        return elapsedSinceDisconnectMs >= 1 && elapsedSinceDisconnectMs <= maxReconnectWindowMs
    }
}
