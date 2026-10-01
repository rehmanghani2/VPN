import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let channelName = "com.vpnplatform.app/vpn"
  private let appGroupIdentifier = "group.com.antigravity.vpn"
  private var vpnChannel: FlutterMethodChannel?
  private var vpnManager: NETunnelProviderManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      vpnChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      setupVpnChannel()
    }

    loadTunnelManager()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupVpnChannel() {
    vpnChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "startTunnel":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing tunnel parameters", details: nil))
          return
        }
        self.startVpn(with: args, result: result)

      case "stopTunnel":
        self.stopVpn(result: result)

      case "getTunnelState":
        let state = self.currentTunnelStateString()
        result(state)

      case "getTunnelStatistics":
        let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier)
        let bytesIn = sharedDefaults?.integer(forKey: "bytesIn") ?? 0
        let bytesOut = sharedDefaults?.integer(forKey: "bytesOut") ?? 0
        let lastHandshake = sharedDefaults?.double(forKey: "lastHandshake") ?? 0
        let isConnected = (self.currentTunnelStateString() == "connected")

        result([
          "bytesIn": bytesIn,
          "bytesOut": bytesOut,
          "lastHandshake": Int(lastHandshake * 1000), // in milliseconds
          "isConnected": isConnected
        ])

      case "openVpnSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Observe tunnel status notifications from iOS system
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(tunnelStatusDidChange(_:)),
      name: .NEVPNStatusDidChange,
      object: nil
    )
  }

  private func loadTunnelManager(completion: (() -> Void)? = nil) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
      if let manager = managers?.first {
        self?.vpnManager = manager
      } else {
        let newManager = NETunnelProviderManager()
        newManager.localizedDescription = "Antigravity VPN"
        self?.vpnManager = newManager
      }
      completion?()
    }
  }

  private func startVpn(with args: [String: Any], result: @escaping FlutterResult) {
    loadTunnelManager { [weak self] in
      guard let self = self, let manager = self.vpnManager else {
        result(FlutterError(code: "VPN_MANAGER_UNAVAILABLE", message: "Failed to initialize VPN manager", details: nil))
        return
      }

      let serverName = args["serverName"] as? String ?? "VPN Server"
      let endpoint = args["endpoint"] as? String ?? "127.0.0.1:51820"

      var modifiedArgs = args
      modifiedArgs["killSwitchEnabled"] = args["killSwitch"] as? Bool ?? false

      let protocolConfig = NETunnelProviderProtocol()
      protocolConfig.providerBundleIdentifier = "com.vpnplatform.app.vpn-client.network-extension"
      protocolConfig.serverAddress = endpoint
      protocolConfig.providerConfiguration = modifiedArgs

      manager.protocolConfiguration = protocolConfig
      manager.localizedDescription = "Antigravity VPN (\(serverName))"
      manager.isEnabled = true

      manager.saveToPreferences { error in
        if let error = error {
          result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
          return
        }

        manager.loadFromPreferences { error in
          if let error = error {
            result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
            return
          }

          do {
            try manager.connection.startVPNTunnel(options: nil)
            result(true)
          } catch {
            result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private func stopVpn(result: FlutterResult) {
    guard let manager = vpnManager else {
      result(true)
      return
    }
    manager.connection.stopVPNTunnel()
    result(true)
  }

  private func currentTunnelStateString() -> String {
    guard let manager = vpnManager else { return "disconnected" }
    switch manager.connection.status {
    case .connected: return "connected"
    case .connecting, .reasserting: return "connecting"
    case .disconnecting: return "disconnecting"
    default: return "disconnected"
    }
  }

  @objc private func tunnelStatusDidChange(_ notification: Notification) {
    let state = currentTunnelStateString()
    vpnChannel?.invokeMethod("onTunnelStateChanged", arguments: ["state": state])
  }
}
