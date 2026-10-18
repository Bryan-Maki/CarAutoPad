import Foundation

public enum VideoStarvationPolicy {

    public static let adviseAfterStarvedSessions: Int = 3

    public static func shouldAdvise(consecutiveStarvedSessions: Int) -> Bool {
        return consecutiveStarvedSessions == adviseAfterStarvedSessions
    }

    public static func shouldCap(consecutiveStarvedSessions: Int) -> Bool {
        return consecutiveStarvedSessions >= adviseAfterStarvedSessions
    }

    public static func nextStreak(current: Int, reachedHandshake: Bool, renderedAnyFrame: Bool) -> Int {
        if !reachedHandshake {
            return current
        } else if renderedAnyFrame {
            return 0
        } else {
            return current + 1
        }
    }
}
