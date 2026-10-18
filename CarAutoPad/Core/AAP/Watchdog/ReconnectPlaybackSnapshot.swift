import Foundation

public final class ReconnectPlaybackSnapshot: @unchecked Sendable {
    public struct Resume: Sendable, Equatable {
        public let wasPlaying: Bool
        public let elapsedMs: Int64

        public init(wasPlaying: Bool, elapsedMs: Int64) {
            self.wasPlaying = wasPlaying
            self.elapsedMs = elapsedMs
        }
    }

    private let lock = NSLock()
    private var wasPlaying: Bool = false
    private var disconnectedAt: Int64 = 0

    public init() {}

    public func onDisconnected(lastPlaying: Bool?, now: Int64, deliberate: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if deliberate {
            wasPlaying = false
        } else if let last = lastPlaying {
            wasPlaying = last
            disconnectedAt = now
        }
    }

    public func consume(now: Int64) -> Resume {
        lock.lock()
        defer { lock.unlock() }

        let result = Resume(wasPlaying: wasPlaying, elapsedMs: now - disconnectedAt)
        wasPlaying = false
        return result
    }
}
