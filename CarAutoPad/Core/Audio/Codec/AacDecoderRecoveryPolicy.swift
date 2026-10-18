import Foundation

public enum AacDecoderRecoveryPolicy {
    public static let maxRebuilds = 3

    public static let minSpacingMs: Int64 = 1_000

    public static func allowsRebuild(rebuildsSoFar: Int, sinceLastRebuildMs: Int64) -> Bool {
        return rebuildsSoFar < maxRebuilds && (rebuildsSoFar == 0 || sinceLastRebuildMs >= minSpacingMs)
    }
}
