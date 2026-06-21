/// Misc app-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Digital Mitro';
  static const String tagline = 'One Team. All Conversations. Connected.';

  // Secure storage keys
  static const String storageTokenKey = 'dm_auth_token';
  static const String storageUserTypeKey = 'dm_user_type';
  static const String storageUserJsonKey = 'dm_user_json';
  static const String storageRememberMeKey = 'dm_remember_me';

  // User types — mirrors backend `userType` values from /mobile/login
  static const String roleEmployee = 'employee';
  static const String roleAdmin = 'admin';
  static const String roleSuperAdmin = 'superadmin';
  static const String roleClient = 'client';
}
