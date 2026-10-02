import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyDeviceId = 'device_id';
  static const String _keyDevicePubKey = 'device_pub_key';
  static const String _keyDevicePrivKey = 'device_priv_key';
  static const String _keyKillSwitch = 'kill_switch';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keySplitTunnelingEnabled = 'split_tunneling_enabled';
  static const String _keySplitTunnelingMode = 'split_tunneling_mode';
  static const String _keySplitTunnelingApps = 'split_tunneling_apps';
  static const String _keyBypassLocalLan = 'bypass_local_lan';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Token management
  Future<void> saveTokens({required String access, required String refresh}) async {
    await _prefs.setString(_keyAccessToken, access);
    await _prefs.setString(_keyRefreshToken, refresh);
  }

  String? get accessToken => _prefs.getString(_keyAccessToken);
  String? get refreshToken => _prefs.getString(_keyRefreshToken);

  Future<void> clearTokens() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
  }

  // Device UUID persistence
  String getOrCreateDeviceUuid() {
    String? id = _prefs.getString(_keyDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  // Device WireGuard Mock / Local Cryptographic Keypair
  Future<void> saveDeviceKeys({required String pubKey, required String privKey}) async {
    await _prefs.setString(_keyDevicePubKey, pubKey);
    await _prefs.setString(_keyDevicePrivKey, privKey);
  }

  String? get devicePublicKey => _prefs.getString(_keyDevicePubKey);
  String? get devicePrivateKey => _prefs.getString(_keyDevicePrivKey);

  // Settings
  bool get isKillSwitchEnabled => _prefs.getBool(_keyKillSwitch) ?? false;
  Future<void> setKillSwitch(bool value) async => await _prefs.setBool(_keyKillSwitch, value);

  bool get isAutoConnectEnabled => _prefs.getBool(_keyAutoConnect) ?? false;
  Future<void> setAutoConnect(bool value) async => await _prefs.setBool(_keyAutoConnect, value);

  // Split Tunneling
  bool get isSplitTunnelingEnabled => _prefs.getBool(_keySplitTunnelingEnabled) ?? false;
  Future<void> setSplitTunneling(bool value) async => await _prefs.setBool(_keySplitTunnelingEnabled, value);

  // Mode: 'bypass' (exclude apps from VPN) or 'only_vpn' (only route selected apps through VPN)
  String get splitTunnelingMode => _prefs.getString(_keySplitTunnelingMode) ?? 'bypass';
  Future<void> setSplitTunnelingMode(String mode) async => await _prefs.setString(_keySplitTunnelingMode, mode);

  List<String> get splitTunnelingApps => _prefs.getStringList(_keySplitTunnelingApps) ?? [];
  Future<void> setSplitTunnelingApps(List<String> apps) async => await _prefs.setStringList(_keySplitTunnelingApps, apps);

  bool get isLocalLanBypassEnabled => _prefs.getBool(_keyBypassLocalLan) ?? true;
  Future<void> setLocalLanBypass(bool value) async => await _prefs.setBool(_keyBypassLocalLan, value);

  // VPN Protocol / Stealth Obfuscation
  static const String _keyVpnProtocol = 'vpn_protocol'; // 'wireguard' or 'stealth_obfuscated'
  String get vpnProtocol => _prefs.getString(_keyVpnProtocol) ?? 'wireguard';
  Future<void> setVpnProtocol(String protocol) async => await _prefs.setString(_keyVpnProtocol, protocol);

  bool get isStealthModeEnabled => vpnProtocol == 'stealth_obfuscated';

  // Threat Shield (DNS Ad-blocking & Malware Filtering)
  static const String _keyThreatShieldLevel = 'threat_shield_level'; // 'off', 'malware_only', 'all'
  String get threatShieldLevel => _prefs.getString(_keyThreatShieldLevel) ?? 'all';
  Future<void> setThreatShieldLevel(String level) async => await _prefs.setString(_keyThreatShieldLevel, level);

  // Phase 15: Post-Quantum WireGuard & Automatic Key Rotation
  static const String _keyPostQuantumEnabled = 'post_quantum_enabled';
  bool get isPostQuantumEnabled => _prefs.getBool(_keyPostQuantumEnabled) ?? true; // Enabled by default for maximum future-proofing
  Future<void> setPostQuantumEnabled(bool value) async => await _prefs.setBool(_keyPostQuantumEnabled, value);

  static const String _keyAutoKeyRotation = 'auto_key_rotation';
  bool get isAutoKeyRotationEnabled => _prefs.getBool(_keyAutoKeyRotation) ?? true;
  Future<void> setAutoKeyRotation(bool value) async => await _prefs.setBool(_keyAutoKeyRotation, value);

  static const String _keyLastKeyRotatedAt = 'last_key_rotated_at';
  DateTime? get lastKeyRotatedAt {
    final str = _prefs.getString(_keyLastKeyRotatedAt);
    return str != null ? DateTime.tryParse(str) : null;
  }
  Future<void> setLastKeyRotatedAt(DateTime dt) async => await _prefs.setString(_keyLastKeyRotatedAt, dt.toIso8601String());

  // Phase 16: Smart Quality Prober & Auto-Failover
  static const String _keyAutoFailover = 'auto_failover';
  bool get isAutoFailoverEnabled => _prefs.getBool(_keyAutoFailover) ?? true;
  Future<void> setAutoFailover(bool value) async => await _prefs.setBool(_keyAutoFailover, value);

  static const String _keyFailoverLatencyThreshold = 'failover_latency_threshold';
  int get failoverLatencyThresholdMs => _prefs.getInt(_keyFailoverLatencyThreshold) ?? 220; // 220ms threshold
  Future<void> setFailoverLatencyThreshold(int ms) async => await _prefs.setInt(_keyFailoverLatencyThreshold, ms);
}
