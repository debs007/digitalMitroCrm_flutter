import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/network/api_exception.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide auth state. [AppShell] and [LoginScreen] both listen to this
/// via Provider so the whole app reacts instantly to login/logout.
class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  bool isLoading = false;
  String? errorMessage;

  /// Called once on app start to silently restore a saved session.
  Future<void> tryRestoreSession() async {
    try {
      final restored = await AuthService.instance.restoreSession();
      if (restored != null) {
        user = restored;
        status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loggedInUser = await AuthService.instance.login(email: email, password: password);
      user = loggedInUser;
      status = AuthStatus.authenticated;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : 'Login failed. Please try again.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final refreshed = await AuthService.instance.refreshProfile();
      user = refreshed;
      notifyListeners();
    } catch (_) {
      // Silently ignore — keep showing the cached profile.
    }
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
