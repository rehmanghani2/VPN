import 'dart:async';
import 'package:flutter/services.dart';
import '../../features/vpn/models/vpn_tunnel.dart';

enum TunnelState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  error,
}

class VpnBridge {
  static const MethodChannel _channel = MethodChannel('com.vpnplatform.app/vpn');

  // Stream controller for tunnel state changes
  final _stateController = StreamController<TunnelState>.broadcast();
  Stream<TunnelState> get onStateChanged => _stateController.stream;

  // Phase 15: In-App Connection Diagnostics & Log Exporter
  final List<Map<String, dynamic>> _diagnosticLogs = [];
  final _logController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onLogReceived => _logController.stream;
  List<Map<String, dynamic>> get diagnosticLogs => List.unmodifiable(_diagnosticLogs);

  TunnelState _currentState = TunnelState.disconnected;
  TunnelState get currentState => _currentState;

  VpnBridge() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
    addLog('INFO', 'VpnBridge initialized and ready.');
  }

  void addLog(String level, String message, {Map<String, dynamic>? meta}) {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      ...?meta != null ? {'meta': meta} : null,
    };
    _diagnosticLogs.add(entry);
    if (_diagnosticLogs.length > 500) _diagnosticLogs.removeAt(0); // keep rolling buffer
    _logController.add(entry);
  }

  void clearLogs() {
    _diagnosticLogs.clear();
    addLog('INFO', 'Diagnostic log buffer reset.');
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTunnelStateChanged':
        final String stateStr = call.arguments['state'] ?? 'disconnected';
        _currentState = _parseState(stateStr);
        _stateController.add(_currentState);
        addLog('TUNNEL', 'Native tunnel state changed to: $stateStr', meta: {'state': stateStr});
        break;
      case 'onTunnelLog':
        final String logMsg = call.arguments['log'] ?? '';
        final String level = call.arguments['level'] ?? 'DEBUG';
        addLog(level, logMsg);
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
    addLog('INFO', 'Initiating tunnel connection to ${config.serverName} (${config.endpoint})');
    if (config.isPostQuantum) {
      addLog('SEC', 'Enforcing Post-Quantum WireGuard hybrid mode (${config.postQuantumAlgorithm})');
    }

    try {
      final Map<String, dynamic> tunnelArgs = config.toJson();
      if (splitTunnelConfig != null) {
        tunnelArgs.addAll(splitTunnelConfig);
        addLog('INFO', 'Configuring split tunneling: ${splitTunnelConfig['splitTunnelingMode']} mode');
      }
      tunnelArgs['killSwitch'] = killSwitch;
      if (killSwitch) {
        addLog('SEC', 'Hardened Kill Switch enabled: blocking non-VPN socket leaks');
      }

      final bool result = await _channel.invokeMethod('startTunnel', tunnelArgs);
      if (result) {
        _currentState = TunnelState.connected;
        addLog('SUCCESS', 'Tunnel successfully established with ${config.serverName}');
      } else {
        _currentState = TunnelState.error;
        addLog('ERROR', 'Platform tunnel establishment returned false');
      }
      _stateController.add(_currentState);
      return result;
    } on MissingPluginException {
      // In development / emulator when native channel is not yet linked:
      // Provide simulated realistic tunnel transition
      addLog('WARN', 'Native channel not found (Simulated runtime fallback active)');
      await Future.delayed(const Duration(milliseconds: 1200));
      _currentState = TunnelState.connected;
      _stateController.add(_currentState);
      addLog('SUCCESS', 'Simulated tunnel connected to ${config.serverName}');
      return true;
    } catch (e) {
      _currentState = TunnelState.error;
      _stateController.add(_currentState);
      addLog('ERROR', 'Tunnel initiation exception: $e');
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
      case 'reconnecting':
        return TunnelState.reconnecting;
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
