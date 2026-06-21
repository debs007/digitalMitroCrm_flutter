import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final ApiClient _api = ApiClient.instance;

  /// Updates the logged-in user's own profile. Admins/SuperAdmins use the
  /// dedicated /auth/admin/profile endpoint; Employees use /auth/:id with
  /// their own id (the UI only exposes name + phone to keep this sane —
  /// email/shift type stay admin-controlled even though the raw endpoint
  /// would technically allow more).
  Future<void> updateMyProfile(AppUser user, {String? name, String? phone, String? password}) async {
    if (user.isAdmin) {
      await _api.put(ApiConstants.adminProfile, data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (password != null && password.isNotEmpty) 'password': password,
      });
    } else {
      await _api.put(ApiConstants.updateEmployeeProfile(user.id), data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      });
    }
  }

  Future<String> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
    });
    final res = await _api.dio.post(ApiConstants.profileAvatar, data: formData);
    final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
    final profile = data['profile'] is Map ? Map<String, dynamic>.from(data['profile']) : {};
    return profile['avatar']?.toString() ?? '';
  }

  Future<void> removeAvatar() async {
    await _api.delete(ApiConstants.profileAvatar);
  }
}
