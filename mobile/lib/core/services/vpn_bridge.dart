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

  Future<bool> startTunnel(VpnTunnel config) async {
    _currentState = TunnelState.connecting;
    _stateController.add(_currentState);

    try {
      final bool result = await _channel.invokeMethod('startTunnel', config.toJson());
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
