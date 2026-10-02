import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vpn_bridge.dart';
import '../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'models/vpn_server.dart';
import 'models/vpn_tunnel.dart';
import 'models/vpn_statistics.dart';

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

  // Real-time Performance Telemetry
  VpnStatistics _statistics = const VpnStatistics();
  Timer? _telemetryTimer;
  int _prevRxBytes = 0;
  int _prevTxBytes = 0;
  final List<double> _rxHistory = [];
  final List<double> _txHistory = [];

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
  VpnStatistics get statistics => _statistics;

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
          'protocol': _storage.vpnProtocol,
          'threatShieldLevel': _storage.threatShieldLevel,
          'enablePostQuantum': _storage.isPostQuantumEnabled,
        },
      );

      final tunnelData = res.data['tunnel'];
      _currentTunnel = VpnTunnel.fromJson(tunnelData);

      // 2. Invoke OS tunnel bridge with Split Tunneling & Kill Switch settings
      Map<String, dynamic>? splitTunnelConfig;
      if (_storage.isSplitTunnelingEnabled) {
        splitTunnelConfig = {
          'splitTunnelingEnabled': true,
          'splitTunnelingMode': _storage.splitTunnelingMode,
          'splitTunnelingApps': _storage.splitTunnelingApps,
          'bypassLocalLan': _storage.isLocalLanBypassEnabled,
        };
      }
      final bool killSwitch = _storage.isKillSwitchEnabled;

      final bool started = await _bridge.startTunnel(
        _currentTunnel!,
        splitTunnelConfig: splitTunnelConfig,
        killSwitch: killSwitch,
      );
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
        Map<String, dynamic>? splitConfig;
        if (_storage.isSplitTunnelingEnabled) {
          splitConfig = {
            'splitTunnelingEnabled': true,
            'splitTunnelingMode': _storage.splitTunnelingMode,
            'splitTunnelingApps': _storage.splitTunnelingApps,
            'bypassLocalLan': _storage.isLocalLanBypassEnabled,
          };
        }
        await _bridge.startTunnel(
          _currentTunnel!,
          splitTunnelConfig: splitConfig,
          killSwitch: _storage.isKillSwitchEnabled,
        );
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

  /// Phase 15: Rotate WireGuard Cryptographic Keypair and Request Post-Quantum Rekey
  Future<Map<String, dynamic>> rotateCryptographicKeys() async {
    _bridge.addLog('SEC', 'Initiating cryptographic keypair rotation...');

    // Generate local random Curve25519 public/private keys simulation
    final randomBytes = List<int>.generate(32, (i) => math.Random.secure().nextInt(256));
    final newPubKey = base64Encode(randomBytes);
    final newPrivKey = base64Encode(List<int>.generate(32, (i) => math.Random.secure().nextInt(256)));

    final deviceId = _storage.getOrCreateDeviceUuid();

    try {
      final res = await _api.client.post(
        ApiConstants.rotateKey,
        data: {
          'deviceId': deviceId,
          'newPublicKey': newPubKey,
          'enablePostQuantum': _storage.isPostQuantumEnabled,
        },
      );

      // Save new keypair locally
      await _storage.saveDeviceKeys(pubKey: newPubKey, privKey: newPrivKey);
      await _storage.setLastKeyRotatedAt(DateTime.now());

      _bridge.addLog(
        'SUCCESS',
        'Cryptographic keys rotated successfully. New public key: ${newPubKey.substring(0, 10)}...',
        meta: res.data,
      );

      notifyListeners();
      return res.data;
    } catch (e) {
      _bridge.addLog('ERROR', 'Key rotation failed: $e');
      rethrow;
    }
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
    _startTelemetry();
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedDuration = Duration.zero;
    _stopTelemetry();
  }

  void _startTelemetry() {
    _stopTelemetry();
    _prevRxBytes = 0;
    _prevTxBytes = 0;
    _rxHistory.clear();
    _txHistory.clear();

    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!isConnected) return;

      final statsMap = await _bridge.getTunnelStatistics();

      double currentRxSpeed = 0;
      double currentTxSpeed = 0;
      int totalRx = 0;
      int totalTx = 0;
      int ping = 28;
      int lastHandshake = _connectedDuration.inSeconds % 25;

      if (statsMap != null && statsMap.containsKey('rxBytes')) {
        totalRx = statsMap['rxBytes'] as int? ?? 0;
        totalTx = statsMap['txBytes'] as int? ?? 0;
        ping = statsMap['pingMs'] as int? ?? 32;
        lastHandshake = statsMap['lastHandshake'] as int? ?? lastHandshake;

        if (_prevRxBytes > 0) {
          currentRxSpeed = math.max(0.0, (totalRx - _prevRxBytes).toDouble());
          currentTxSpeed = math.max(0.0, (totalTx - _prevTxBytes).toDouble());
        }
        _prevRxBytes = totalRx;
        _prevTxBytes = totalTx;
      } else {
        // Simulated realistic network pulses for web / desktop preview
        final random = math.Random();
        currentRxSpeed = 1024 * 1024 * (4.2 + random.nextDouble() * 5.8); // 4.2 - 10 MB/s
        currentTxSpeed = 1024 * 512 * (1.1 + random.nextDouble() * 2.1);   // 560 KB - 1.6 MB/s
        ping = 24 + random.nextInt(14);

        totalRx = (_statistics.totalRxBytes + currentRxSpeed.toInt());
        totalTx = (_statistics.totalTxBytes + currentTxSpeed.toInt());
      }

      _rxHistory.add(currentRxSpeed);
      if (_rxHistory.length > 30) _rxHistory.removeAt(0);

      _txHistory.add(currentTxSpeed);
      if (_txHistory.length > 30) _txHistory.removeAt(0);

      _statistics = VpnStatistics(
        totalRxBytes: totalRx,
        totalTxBytes: totalTx,
        rxSpeed: currentRxSpeed,
        txSpeed: currentTxSpeed,
        pingMs: ping,
        lastHandshakeSeconds: lastHandshake,
        rxHistory: List.unmodifiable(_rxHistory),
        txHistory: List.unmodifiable(_txHistory),
      );

      notifyListeners();
    });
  }

  void _stopTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _statistics = const VpnStatistics();
    _rxHistory.clear();
    _txHistory.clear();
    _prevRxBytes = 0;
    _prevTxBytes = 0;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _telemetryTimer?.cancel();
    _bridgeSub?.cancel();
    super.dispose();
  }
}
