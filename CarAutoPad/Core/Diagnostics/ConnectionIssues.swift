import Foundation

public enum ConnectionIssue: String, CaseIterable, Equatable, Codable {
    case wifiRadioOff
    case headunitServerNotAnswering
    case connectionRefused5277
    case tlsHandshakeFailed
    case videoLinkTooSlow
    case noDeviceDiscovered
    case headunitServerStuckAfterRetries

    public var title: String {
        switch self {
        case .wifiRadioOff:
            return L10n.issueWifiOffTitle
        case .headunitServerNotAnswering:
            return L10n.issueHeadunitNotAnsweringTitle
        case .connectionRefused5277:
            return L10n.issueRefused5277Title
        case .tlsHandshakeFailed:
            return L10n.issueTlsFailedTitle
        case .videoLinkTooSlow:
            return L10n.issueVideoSlowTitle
        case .noDeviceDiscovered:
            return L10n.issueNoDeviceTitle
        case .headunitServerStuckAfterRetries:
            return L10n.issueStuckAfterRetriesTitle
        }
    }

    public var resolutionAdvice: String {
        switch self {
        case .wifiRadioOff:
            return L10n.issueWifiOffAdvice
        case .headunitServerNotAnswering:
            return L10n.issueHeadunitNotAnsweringAdvice
        case .connectionRefused5277:
            return L10n.issueRefused5277Advice
        case .tlsHandshakeFailed:
            return L10n.issueTlsFailedAdvice
        case .videoLinkTooSlow:
            return L10n.issueVideoSlowAdvice
        case .noDeviceDiscovered:
            return L10n.issueNoDeviceAdvice
        case .headunitServerStuckAfterRetries:
            return L10n.issueStuckAfterRetriesAdvice
        }
    }
}

public struct StandingIssue: Equatable, Codable {
    public let issue: ConnectionIssue
    public let raisedAtEpochMs: Int64

    public init(issue: ConnectionIssue, raisedAtEpochMs: Int64) {
        self.issue = issue
        self.raisedAtEpochMs = raisedAtEpochMs
    }
}

public final class ConnectionIssueStore: @unchecked Sendable {
    public static let shared = ConnectionIssueStore()

    private let lock = NSLock()
    private var issues: [StandingIssue] = []
    private let defaultsKey = "carautopad-standing-connection-issues"

    public init() {
        loadPersisted()
    }

    public func raise(issue: ConnectionIssue, epochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        lock.lock()
        defer { lock.unlock() }
        issues.removeAll { $0.issue == issue }
        issues.append(StandingIssue(issue: issue, raisedAtEpochMs: epochMs))
        persist()
    }

    public func clear(issue: ConnectionIssue) {
        lock.lock()
        defer { lock.unlock() }
        issues.removeAll { $0.issue == issue }
        persist()
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        issues.removeAll()
        persist()
    }

    public func clearTransientSessionIssues() {
        let transient: Set<ConnectionIssue> = [
            .noDeviceDiscovered,
            .connectionRefused5277,
            .tlsHandshakeFailed,
            .headunitServerNotAnswering,
            .headunitServerStuckAfterRetries,
            .videoLinkTooSlow
        ]
        lock.lock()
        defer { lock.unlock() }
        let before = issues.count
        issues.removeAll { transient.contains($0.issue) }
        if issues.count != before {
            persist()
        }
    }

    public func currentIssues() -> [StandingIssue] {
        lock.lock()
        defer { lock.unlock() }
        return issues
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(issues) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    private func loadPersisted() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([StandingIssue].self, from: data) {
            issues = decoded
        }
    }
}
