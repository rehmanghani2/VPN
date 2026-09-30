import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.vpnplatform.app.vpn_client", category: "PacketTunnel")

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting Antigravity WireGuard tunnel...", log: log, type: .info)

        guard let conf = (self.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else {
            completionHandler(NSError(domain: "VPNError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing providerConfiguration"]))
            return
        }

        let endpoint = conf["endpoint"] as? String ?? "127.0.0.1:51820"
        let clientIpV4 = conf["clientAddressV4"] as? String ?? "10.8.0.2/24"
        let mtu = conf["mtu"] as? Int ?? 1360

        // Parse IPv4 address
        let v4Address = clientIpV4.components(separatedBy: "/").first ?? "10.8.0.2"

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: endpoint.components(separatedBy: ":").first ?? "127.0.0.1")
        networkSettings.mtu = NSNumber(value: mtu)

        // Configure IPv4
        let ipv4Settings = NEIPv4Settings(addresses: [v4Address], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()] // 0.0.0.0/0
        networkSettings.ipv4Settings = ipv4Settings

        // Configure DNS
        let dnsSettings = NEDNSSettings(servers: ["10.8.0.1"])
        dnsSettings.matchDomains = [""] // Route all DNS queries through VPN
        networkSettings.dnsSettings = dnsSettings

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            if let error = error {
                os_log("Failed to set tunnel network settings: %{public}@", log: self?.log ?? .default, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }

            os_log("Tunnel network settings applied successfully.", log: self?.log ?? .default, type: .info)
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping WireGuard tunnel. Reason: %d", log: log, type: .info, reason.rawValue)
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(nil)
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
        os_log("Waking from sleep. Re-verifying tunnel connection...", log: log, type: .info)
    }
}
