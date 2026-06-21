import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/socket_service.dart';
import '../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final ApiClient _api = ApiClient.instance;

  /// Logs in via the unified /mobile/login endpoint. The backend
  /// auto-detects whether the email belongs to an Employee, Admin,
  /// SuperAdmin, or Client — the "Login As" tab in the UI is a visual
  /// hint only and isn't sent to the server.
  Future<AppUser> login({required String email, required String password}) async {
    final res = await _api.post(
      ApiConstants.mobileLogin,
      data: {'email': email, 'password': password},
    );

    final token = res['token']?.toString() ?? '';
    final userType = res['userType']?.toString() ?? 'employee';
    final userJson = res['user'] is Map ? Map<String, dynamic>.from(res['user']) : <String, dynamic>{};

    await SecureStorage.instance.saveSession(token: token, userType: userType, user: userJson);
    await SocketService.instance.connect();

    return AppUser.fromJson(userJson, userType);
  }

  /// Restores a session from secure storage on app start, if any.
  Future<AppUser?> restoreSession() async {
    final token = await SecureStorage.instance.getToken();
    final userType = await SecureStorage.instance.getUserType();
    final userJson = await SecureStorage.instance.getUserJson();
    if (token == null || token.isEmpty || userJson == null || userType == null) {
      return null;
    }
    await SocketService.instance.connect();
    return AppUser.fromJson(userJson, userType);
  }

  /// Refreshes the profile from the server (e.g. after permission changes).
  Future<AppUser> refreshProfile() async {
    final res = await _api.get(ApiConstants.mobileProfile);
    final userType = res['userType']?.toString() ?? 'employee';
    final userJson = res['user'] is Map ? Map<String, dynamic>.from(res['user']) : <String, dynamic>{};

    final token = await SecureStorage.instance.getToken() ?? '';
    await SecureStorage.instance.saveSession(token: token, userType: userType, user: userJson);

    return AppUser.fromJson(userJson, userType);
  }

  Future<void> registerFcmToken(String fcmToken) async {
    try {
      await _api.post(ApiConstants.mobileFcmToken, data: {'token': fcmToken});
    } catch (_) {
      // Non-fatal — app should still work without push notifications.
    }
  }

  Future<void> logout() async {
    try {
      await _api.delete(ApiConstants.mobileFcmToken);
    } catch (_) {
      // Ignore — we're logging out regardless.
    }
    SocketService.instance.disconnect();
    await SecureStorage.instance.clearSession();
  }
}
