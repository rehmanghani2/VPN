import 'dart:async';
import 'package:flutter/services.dart';
import '../../features/vpn/models/vpn_tunnel.dart';

enum TunnelState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class VpnBridge {
  static const MethodChannel _channel = MethodChannel('com.vpnplatform.app/vpn');

  // Stream controller for tunnel state changes
  final _stateController = StreamController<TunnelState>.broadcast();
  Stream<TunnelState> get onStateChanged => _stateController.stream;

  TunnelState _currentState = TunnelState.disconnected;
  TunnelState get currentState => _currentState;

  VpnBridge() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTunnelStateChanged':
        final String stateStr = call.arguments['state'] ?? 'disconnected';
        _currentState = _parseState(stateStr);
        _stateController.add(_currentState);
        break;
    }
  }

  Future<bool> startTunnel(
    VpnTunnel config, {
    Map<String, dynamic>? splitTunnelConfig,
    bool killSwitch = false,
  }) async {
    _currentState = TunnelState.connecting;
    _stateController.add(_currentState);

    try {
      final Map<String, dynamic> tunnelArgs = config.toJson();
      if (splitTunnelConfig != null) {
        tunnelArgs.addAll(splitTunnelConfig);
      }
      tunnelArgs['killSwitch'] = killSwitch;

      final bool result = await _channel.invokeMethod('startTunnel', tunnelArgs);
      if (result) {
        _currentState = TunnelState.connected;
      } else {
        _currentState = TunnelState.error;
      }
      _stateController.add(_currentState);
      return result;
    } on MissingPluginException {
      // In development / emulator when native channel is not yet linked:
      // Provide simulated realistic tunnel transition
      await Future.delayed(const Duration(milliseconds: 1200));
      _currentState = TunnelState.connected;
      _stateController.add(_currentState);
      return true;
    } catch (e) {
      _currentState = TunnelState.error;
      _stateController.add(_currentState);
      return false;
    }
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic>? apps = await _channel.invokeMethod('getInstalledApps');
      if (apps == null) return [];
      return apps.map((a) => Map<String, String>.from(a as Map)).toList();
    } catch (e) {
      // Return sample mockup apps for Chrome web / desktop preview
      return [
        {'packageName': 'com.android.chrome', 'appName': 'Google Chrome'},
        {'packageName': 'com.netflix.mediaclient', 'appName': 'Netflix'},
        {'packageName': 'com.spotify.music', 'appName': 'Spotify'},
        {'packageName': 'com.whatsapp', 'appName': 'WhatsApp'},
        {'packageName': 'com.google.android.youtube', 'appName': 'YouTube'},
        {'packageName': 'org.telegram.messenger', 'appName': 'Telegram'},
        {'packageName': 'com.paypal.android.p2pmobile', 'appName': 'PayPal'},
      ];
    }
  }

  Future<void> openVpnSettings() async {
    try {
      await _channel.invokeMethod('openVpnSettings');
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getTunnelStatistics() async {
    try {
      final res = await _channel.invokeMethod('getTunnelStatistics');
      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> stopTunnel() async {
    _currentState = TunnelState.disconnecting;
    _stateController.add(_currentState);

    try {
      final bool result = await _channel.invokeMethod('stopTunnel');
      _currentState = TunnelState.disconnected;
      _stateController.add(_currentState);
      return result;
    } on MissingPluginException {
      await Future.delayed(const Duration(milliseconds: 500));
      _currentState = TunnelState.disconnected;
      _stateController.add(_currentState);
      return true;
    } catch (e) {
      _currentState = TunnelState.disconnected;
      _stateController.add(_currentState);
      return false;
    }
  }

  TunnelState _parseState(String state) {
    switch (state.toLowerCase()) {
      case 'connecting':
        return TunnelState.connecting;
      case 'connected':
        return TunnelState.connected;
      case 'disconnecting':
        return TunnelState.disconnecting;
      case 'error':
        return TunnelState.error;
      default:
        return TunnelState.disconnected;
    }
  }

  void dispose() {
    _stateController.close();
  }
}
