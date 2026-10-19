import Foundation

public final class AutomaticReconnect: @unchecked Sendable {
    public static let defaultMaxAttempts: Int = 3
    public static let defaultRetryDelayMs: Int64 = 3_000

    public let maxAttempts: Int
    public let retryDelayMs: Int64
    public private(set) var attemptCount: Int = 0

    private let lock = NSLock()
    private var pendingTask: Task<Void, Never>?
    private var ownsCheck: (@Sendable () -> Bool)?

    private let currentState: (@Sendable () -> AnyObject?)?
    private let isStopping: @Sendable () -> Bool

    public var isScheduled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingTask != nil
    }

    public init(
        currentState: (@Sendable () -> AnyObject?)? = nil,
        isStopping: @escaping @Sendable () -> Bool = { false },
        maxAttempts: Int = defaultMaxAttempts,
        retryDelayMs: Int64 = defaultRetryDelayMs
    ) {
        self.currentState = currentState
        self.isStopping = isStopping
        self.maxAttempts = maxAttempts
        self.retryDelayMs = retryDelayMs
    }

    public func resetAttempts() {
        lock.lock()
        defer { lock.unlock() }
        attemptCount = 0
        pendingTask?.cancel()
        pendingTask = nil
        ownsCheck = nil
    }

    public func delaySeconds(forAttempt attempt: Int) -> TimeInterval {
        return Double(retryDelayMs) / 1000.0
    }

    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        pendingTask?.cancel()
        pendingTask = nil
        ownsCheck = nil
    }

    public func onStateChanged() {
        lock.lock()
        let stopping = isStopping()
        let owns = ownsCheck?() ?? false
        lock.unlock()

        if stopping || !owns {
            cancel()
        }
    }

    public func schedule(
        endedSession: AnyObject,
        delayMs: Int64,
        ownsCheck: (@Sendable () -> Bool)? = nil,
        reconnect: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        if let stateProvider = currentState {
            guard stateProvider() === endedSession else { return }
        }
        guard !isStopping() else { return }

        pendingTask?.cancel()
        attemptCount += 1

        let check = ownsCheck ?? { [weak self, weak endedSession] in
            guard let self = self else { return false }
            if let stateProvider = self.currentState {
                guard let ended = endedSession else { return false }
                return stateProvider() === ended
            }
            return true
        }
        self.ownsCheck = check

        pendingTask = Task { [weak self] in
            let nanos = UInt64(max(0, delayMs)) * 1_000_000
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }

            guard let self = self else { return }
            self.lock.lock()
            self.pendingTask = nil
            let shouldRun = !self.isStopping() && (self.ownsCheck?() == true)
            self.lock.unlock()

            if shouldRun {
                reconnect()
            }
        }
    }
}
