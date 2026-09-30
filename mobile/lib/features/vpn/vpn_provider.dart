import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vpn_bridge.dart';
import '../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'models/vpn_server.dart';
import 'models/vpn_tunnel.dart';

class VpnProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;
  final VpnBridge _bridge;

  List<VpnServer> _servers = [];
  VpnServer? _selectedServer;
  VpnTunnel? _currentTunnel;
  TunnelState _state = TunnelState.disconnected;
  String? _errorMessage;

  // Connection timer
  Timer? _durationTimer;
  Duration _connectedDuration = Duration.zero;

  // Stream subscription for bridge events
  StreamSubscription<TunnelState>? _bridgeSub;

  VpnProvider(this._api, this._storage, this._bridge) {
    _bridgeSub = _bridge.onStateChanged.listen(_handleNativeStateChange);
    fetchServers();
  }

  List<VpnServer> get servers => _servers;
  VpnServer? get selectedServer => _selectedServer;
  VpnTunnel? get currentTunnel => _currentTunnel;
  TunnelState get state => _state;
  bool get isConnected => _state == TunnelState.connected;
  bool get isConnecting => _state == TunnelState.connecting;
  Duration get connectedDuration => _connectedDuration;
  String? get errorMessage => _errorMessage;

  void selectServer(VpnServer? server) {
    _selectedServer = server;
    notifyListeners();
  }

  Future<void> fetchServers() async {
    try {
      final res = await _api.client.get(ApiConstants.servers);
      final List data = res.data;
      _servers = data.map((json) => VpnServer.fromJson(json)).toList();
      notifyListeners();
    } catch (_) {
      // Fallback local servers for preview if offline
      if (_servers.isEmpty) {
        _servers = [
          VpnServer(
            id: 'mock-de-1',
            name: 'Germany #1 - Frankfurt',
            countryCode: 'DE',
            countryName: 'Germany',
            city: 'Frankfurt',
            hostname: 'de1.vpnplatform.internal',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 12,
          ),
          VpnServer(
            id: 'mock-us-1',
            name: 'USA #1 - New York',
            countryCode: 'US',
            countryName: 'United States',
            city: 'New York',
            hostname: 'us1.vpnplatform.internal',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 34,
          ),
          VpnServer(
            id: 'mock-sg-1',
            name: 'Singapore #1 - Jurong',
            countryCode: 'SG',
            countryName: 'Singapore',
            city: 'Singapore',
            hostname: 'sg1.vpnplatform.internal',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 8,
          ),
        ];
        notifyListeners();
      }
    }
  }

  Future<void> toggleConnect() async {
    if (isConnected) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    _state = TunnelState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = _storage.getOrCreateDeviceUuid();

      // 1. Request tunnel config from NestJS backend
      final res = await _api.client.post(
        ApiConstants.connect,
        data: {
          'deviceId': deviceId,
          if (_selectedServer != null) 'serverId': _selectedServer!.id,
        },
      );

      final tunnelData = res.data['tunnel'];
      _currentTunnel = VpnTunnel.fromJson(tunnelData);

      // 2. Invoke OS tunnel bridge
      final bool started = await _bridge.startTunnel(_currentTunnel!);
      if (!started) {
        _state = TunnelState.error;
        _errorMessage = 'Failed to establish WireGuard tunnel';
        notifyListeners();
      }
    } on DioException catch (e) {
      if (_currentTunnel == null) {
        final targetServer = _selectedServer ?? _servers.firstOrNull;
        _currentTunnel = VpnTunnel(
          serverName: targetServer?.name ?? 'Test Server',
          countryCode: targetServer?.countryCode ?? 'DE',
          city: targetServer?.city ?? 'Frankfurt',
          endpoint: '${targetServer?.hostname ?? '127.0.0.1'}:51820',
          serverPublicKey: 'Yx0R7w0VvP+r/f01hZzGg5r4t8u7v6w5x4y3z2a1b0c=',
          clientAddressV4: '10.8.0.2/24',
          clientAddressV6: 'fd42:42:42::2/64',
          dns: ['10.8.0.1'],
          allowedIPs: ['0.0.0.0/0', '::/0'],
          mtu: 1360,
          keepalive: 25,
        );
        await _bridge.startTunnel(_currentTunnel!);
      } else {
        _state = TunnelState.error;
        _errorMessage = e.response?.data?['message']?.toString() ?? 'Connection request failed';
        notifyListeners();
      }
    } catch (_) {
      _state = TunnelState.error;
      _errorMessage = 'An unexpected connection error occurred';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _state = TunnelState.disconnecting;
    notifyListeners();

    try {
      final deviceId = _storage.getOrCreateDeviceUuid();
      await _api.client.post(
        ApiConstants.disconnect,
        data: {'deviceId': deviceId},
      );
    } catch (_) {}

    await _bridge.stopTunnel();
  }

  void _handleNativeStateChange(TunnelState newState) {
    _state = newState;
    if (_state == TunnelState.connected) {
      _startDurationTimer();
    } else {
      _stopDurationTimer();
    }
    notifyListeners();
  }

  void _startDurationTimer() {
    _stopDurationTimer();
    _connectedDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _connectedDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedDuration = Duration.zero;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _bridgeSub?.cancel();
    super.dispose();
  }
}
