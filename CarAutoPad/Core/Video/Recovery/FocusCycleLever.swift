import Foundation

public final class FocusCycleLever {
    private let lock = NSLock()
    private var held: Bool = false

    public init() {}

    public func tryClaim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if held { return false }
        held = true
        return true
    }

    public func release() {
        lock.lock()
        defer { lock.unlock() }
        held = false
    }

    public var isHeld: Bool {
        lock.lock()
        defer { lock.unlock() }
        return held
    }
}
