import Foundation

public enum UnresponsivePeerPolicy {

    public static let silentFailuresBeforeBackoff: Int = 3

    public static let silentFailuresBeforeLastTier: Int = 3

    public static let normalRescanMs: Int64 = 3_000

    public static let backoffRescanMs: Int64 = 3_000

    public static let lastTierRescanMs: Int64 = 3_000

    public static func rescanDelayMs(consecutiveSilentFailures: Int) -> Int64 {
        return normalRescanMs
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
