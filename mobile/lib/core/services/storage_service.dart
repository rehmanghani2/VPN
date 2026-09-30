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
}
