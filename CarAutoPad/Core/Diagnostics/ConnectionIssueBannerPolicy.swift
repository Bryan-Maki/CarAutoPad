import Foundation

public enum ConnectionIssueBannerPolicy {
    public static func bannerFor(
        standing: [StandingIssue],
        sessionConnected: Bool,
        dismissedAtEpochMs: Int64? = nil
    ) -> StandingIssue? {
        if sessionConnected {
            return nil
        }

        let filtered: [StandingIssue]
        if let dismissed = dismissedAtEpochMs {
            filtered = standing.filter { $0.raisedAtEpochMs > dismissed }
        } else {
            filtered = standing
        }

        return filtered.max(by: { $0.raisedAtEpochMs < $1.raisedAtEpochMs })
    }
}
