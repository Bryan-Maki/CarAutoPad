import Foundation

public struct InterfaceAddressInfo: Equatable {
    public let name: String
    public let ip: String
    public let netmask: String?
    public let broadcast: String?
}

public enum NetworkAddresses {
    public static func stationIpv4() -> String? {
        let addresses = allInterfaces()
        if let wifi = addresses.first(where: { $0.name == "en0" }) {
            return wifi.ip
        }
        if let altWifi = addresses.first(where: { $0.name.hasPrefix("en") }) {
            return altWifi.ip
        }
        return addresses.first?.ip
    }

    public static func currentWifiIPv4Address() -> String? {
        return stationIpv4()
    }

    public static func allInterfaces() -> [InterfaceAddressInfo] {
        var results: [InterfaceAddressInfo] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return []
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && !isLoopback, let sa = interface.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                var netmaskStr: String? = nil
                var broadcastStr: String? = nil

                if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)

                    if let maskSa = interface.ifa_netmask {
                        var maskHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(maskSa, socklen_t(maskSa.pointee.sa_len), &maskHost, socklen_t(maskHost.count), nil, 0, NI_NUMERICHOST) == 0 {
                            netmaskStr = String(cString: maskHost)
                        }
                    }

                    if let broadSa = interface.ifa_dstaddr {
                        var broadHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(broadSa, socklen_t(broadSa.pointee.sa_len), &broadHost, socklen_t(broadHost.count), nil, 0, NI_NUMERICHOST) == 0 {
                            broadcastStr = String(cString: broadHost)
                        }
                    }

                    results.append(InterfaceAddressInfo(
                        name: name,
                        ip: ip,
                        netmask: netmaskStr,
                        broadcast: broadcastStr
                    ))
                }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }

        return results
    }

    public static func defaultGatewaySuspects() -> [String] {
        var suspects: [String] = []
        let addresses = allInterfaces()
        for iface in addresses {
            if let subnet = DiscoverySubnetPolicy.subnetOf(ipv4: iface.ip) {
                let gatewayHeuristic = "\(subnet).1"
                if gatewayHeuristic != iface.ip && !suspects.contains(gatewayHeuristic) {
                    suspects.append(gatewayHeuristic)
                }
            }
        }
        return suspects
    }

    public static func currentHotspotGatewayIpv4() -> String {
        if let ip = stationIpv4(), let subnet = DiscoverySubnetPolicy.subnetOf(ipv4: ip) {
            return "\(subnet).1"
        }
        return "192.168.43.1"
    }
}
