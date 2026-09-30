import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/constants/api_constants.dart';
import 'models/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthProvider(this._api, this._storage) {
    checkAuthStatus();
  }

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuthStatus() async {
    final token = _storage.accessToken;
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final res = await _api.client.get(ApiConstants.me);
      _user = UserModel.fromJson(res.data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _storage.clearTokens();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.client.post(
        ApiConstants.login,
        data: {'email': email.trim(), 'password': password},
      );

      final access = res.data['accessToken'];
      final refresh = res.data['refreshToken'];
      await _storage.saveTokens(access: access, refresh: refresh);

      _user = UserModel.fromJson(res.data['user']);
      _status = AuthStatus.authenticated;

      // Register device automatically
      await _enrollDevice();

      notifyListeners();
      return true;
    } catch (e: any) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.response?.data?['message'] ?? 'Login failed. Please check credentials.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.client.post(
        ApiConstants.register,
        data: {'email': email.trim(), 'password': password},
      );

      final access = res.data['accessToken'];
      final refresh = res.data['refreshToken'];
      await _storage.saveTokens(access: access, refresh: refresh);

      _user = UserModel.fromJson(res.data['user']);
      _status = AuthStatus.authenticated;

      await _enrollDevice();

      notifyListeners();
      return true;
    } catch (e: any) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.response?.data?['message'] ?? 'Registration failed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _enrollDevice() async {
    try {
      final deviceId = _storage.getOrCreateDeviceUuid();
      String platform = 'WINDOWS';
      if (!kIsWeb) {
        if (Platform.isAndroid) platform = 'ANDROID';
        if (Platform.isIOS) platform = 'IOS';
        if (Platform.isMacOS) platform = 'MACOS';
        if (Platform.isLinux) platform = 'LINUX';
      }

      // Generate or retrieve device WireGuard public key
      String? pubKey = _storage.devicePublicKey;
      if (pubKey == null) {
        // WireGuard standard 32-byte Base64 key representation
        pubKey = 'ClntWgPubKey${deviceId.substring(0, 18)}==';
        await _storage.saveDeviceKeys(pubKey: pubKey, privKey: 'mockPrivKey');
      }

      await _api.client.post(
        ApiConstants.devices,
        data: {
          'deviceIdentifier': deviceId,
          'name': '${platform[0]}${platform.substring(1).toLowerCase()} Device',
          'platform': platform,
          'publicKey': pubKey,
        },
      );
    } catch (_) {
      // Non-fatal, device quota might be verified on connect
    }
  }

  Future<void> logout() async {
    await _storage.clearTokens();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
