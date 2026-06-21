import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Thin wrapper around [FlutterSecureStorage] for everything the app
/// needs to persist between launches: JWT token, the logged-in user's
/// JSON blob, and their resolved user type (employee/admin/superadmin/client).
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveSession({
    required String token,
    required String userType,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: AppConstants.storageTokenKey, value: token);
    await _storage.write(key: AppConstants.storageUserTypeKey, value: userType);
    await _storage.write(key: AppConstants.storageUserJsonKey, value: jsonEncode(user));
  }

  Future<String?> getToken() => _storage.read(key: AppConstants.storageTokenKey);

  Future<String?> getUserType() => _storage.read(key: AppConstants.storageUserTypeKey);

  Future<Map<String, dynamic>?> getUserJson() async {
    final raw = await _storage.read(key: AppConstants.storageUserJsonKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setRememberMe(bool value) =>
      _storage.write(key: AppConstants.storageRememberMeKey, value: value.toString());

  Future<bool> getRememberMe() async {
    final raw = await _storage.read(key: AppConstants.storageRememberMeKey);
    return raw == 'true';
  }

  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.storageTokenKey);
    await _storage.delete(key: AppConstants.storageUserTypeKey);
    await _storage.delete(key: AppConstants.storageUserJsonKey);
    // Note: rememberMe flag is intentionally kept so the login email
    // can stay pre-filled even after logout, if you choose to store it.
  }
}
