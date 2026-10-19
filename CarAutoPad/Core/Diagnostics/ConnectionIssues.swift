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
            return "Search Failed: No Wi-Fi / Hotspot"
        case .headunitServerNotAnswering:
            return "Headunit Server Not Answering"
        case .connectionRefused5277:
            return "Connection Refused (Port 5277)"
        case .tlsHandshakeFailed:
            return "TLS Handshake Failed"
        case .videoLinkTooSlow:
            return "Wireless Link Too Slow"
        case .noDeviceDiscovered:
            return "No Device Found on Network"
        case .headunitServerStuckAfterRetries:
            return "Connection Failed After 3 Retries (Server May Be Stuck)"
        }
    }

    public var resolutionAdvice: String {
        switch self {
        case .wifiRadioOff:
            return "No valid local Wi-Fi IPv4 address detected. Please connect iPad to your phone's personal hotspot or the same Wi-Fi network first."
        case .headunitServerNotAnswering:
            return "Ensure 'Start Headunit Server' is running in Android Auto developer settings on the phone."
        case .connectionRefused5277:
            return "The phone actively refused port 5277. Stop and re-start Headunit Server in Android Auto."
        case .tlsHandshakeFailed:
            return "Cryptographic negotiation failed. Check date/time synchronization or re-pair."
        case .videoLinkTooSlow:
            return "Heavy packet drops on video feed. Move closer to the Wi-Fi hotspot or switch to 5GHz."
        case .noDeviceDiscovered:
            return "Wi-Fi is connected, but no phone responded on port 5277. Make sure 'Start head unit server' is active in Android Auto Developer Settings."
        case .headunitServerStuckAfterRetries:
            return "The phone's Headunit Server appears frozen or unresponsive. Please open Android Auto (⋮ -> Stop head unit server, then Start head unit server) on your phone and try again."
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
