import Foundation

public enum UnresponsivePeerPolicy {

    public static let silentFailuresBeforeBackoff: Int = 3

    public static let silentFailuresBeforeLastTier: Int = 10

    public static let normalRescanMs: Int64 = 10_000

    public static let backoffRescanMs: Int64 = 60_000

    public static let lastTierRescanMs: Int64 = 300_000

    public static func rescanDelayMs(consecutiveSilentFailures: Int) -> Int64 {
        if consecutiveSilentFailures >= silentFailuresBeforeLastTier {
            return lastTierRescanMs
        } else if consecutiveSilentFailures >= silentFailuresBeforeBackoff {
            return backoffRescanMs
        } else {
            return normalRescanMs
        }
    }

    public static func shouldExplain(consecutiveSilentFailures: Int) -> Bool {
        return consecutiveSilentFailures == silentFailuresBeforeBackoff
    }

    public static func countAfterSilentFailure(
        previousCount: Int,
        previousEndpoint: String?,
        endpoint: String?
    ) -> Int {
        if let prev = previousEndpoint, let cur = endpoint, prev == cur {
            return previousCount + 1
        } else {
            return 1
        }
    }
}
