import Foundation

public final class SameEndpointConnectPolicy {
    public init() {}

    private var activeEndpoints = Set<String>()

    public func shouldConnect(endpoint: String) -> Bool {
        return !activeEndpoints.contains(endpoint)
    }

    public func recordConnectionStarted(endpoint: String) {
        activeEndpoints.insert(endpoint)
    }

    public func recordConnectionEnded(endpoint: String) {
        activeEndpoints.remove(endpoint)
    }

    public enum Route: Equatable {
        case adoptHeld
        case join
        case dial
    }

    public static func joins(inFlight: String?, requested: String?) -> Bool {
        guard let inFlight = inFlight, let requested = requested else { return false }
        return inFlight == requested
    }

    public static func route(held: String?, inFlight: String?, requested: String?) -> Route {
        if joins(inFlight: held, requested: requested) {
            return .adoptHeld
        }
        if joins(inFlight: inFlight, requested: requested) {
            return .join
        }
        return .dial
    }

    public static func endpoint(host: String, port: Int) -> String {
        let cleanHost: String
        if let percentIndex = host.firstIndex(of: "%") {
            cleanHost = String(host[..<percentIndex])
        } else {
            cleanHost = host
        }
        let stripped = cleanHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return "\(stripped):\(port)"
    }
}
