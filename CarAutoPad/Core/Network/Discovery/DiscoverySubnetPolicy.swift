import Foundation

public enum DiscoverySubnetPolicy {
    public static func address(stationIpv4: String?, firstInterfaceIpv4: String?) -> String? {
        if let station = stationIpv4, !station.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return station
        }
        if let first = firstInterfaceIpv4, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return first
        }
        return nil
    }

    public static func source(stationIpv4: String?) -> String {
        if let station = stationIpv4, !station.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "the joined WiFi network"
        } else {
            return "the first interface that is up"
        }
    }

    public static func subnetOf(ipv4: String?) -> String? {
        guard let host = ipv4?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            return nil
        }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        for part in parts {
            guard let val = Int(part), val >= 0, val <= 255 else {
                return nil
            }
        }
        return parts.prefix(3).joined(separator: ".")
    }

    public static func generateSubnetCandidates(baseIp: String, maxHosts: Int = 254) -> [String] {
        guard let subnet = subnetOf(ipv4: baseIp) else { return [] }
        var list: [String] = []
        let count = min(max(1, maxHosts), 254)
        for i in 1...count {
            list.append("\(subnet).\(i)")
        }
        return list
    }
}
