import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin_model.dart';

class PickerEmployee {
  final String id;
  final String name;
  final String avatar;
  PickerEmployee({required this.id, required this.name, required this.avatar});
  factory PickerEmployee.fromJson(Map<String, dynamic> json) => PickerEmployee(
        id: (json['_id'] ?? '').toString(),
        name: json['name']?.toString() ?? '',
        avatar: json['avatar']?.toString() ?? '',
      );
}

class PickerChannel {
  final String id;
  final String name;
  final String image;
  PickerChannel({required this.id, required this.name, required this.image});
  factory PickerChannel.fromJson(Map<String, dynamic> json) => PickerChannel(
        id: (json['_id'] ?? '').toString(),
        name: json['name']?.toString() ?? '',
        image: json['image']?.toString() ?? '',
      );
}

class SuperAdminService {
  SuperAdminService._();
  static final SuperAdminService instance = SuperAdminService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<AdminModel>> listAdmins() async {
    final res = await _api.get(ApiConstants.saAdmins);
    final list = res['admins'];
    if (list is List) {
      return list.map((a) => AdminModel.fromJson(Map<String, dynamic>.from(a))).toList();
    }
    return [];
  }

  Future<void> createAdmin({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _api.post(ApiConstants.saAdmins, data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'permissions': AdminPermissions.empty().toJson(),
    });
  }

  Future<void> deleteAdmin(String id) async {
    await _api.delete(ApiConstants.saAdminDelete(id));
  }

  Future<void> updatePermissions(String adminId, AdminPermissions permissions) async {
    await _api.patch(ApiConstants.saAdminPermissions(adminId), data: {
      'permissions': permissions.toJson(),
    });
  }

  Future<void> updateScope({
    required String adminId,
    required bool allEmployees,
    required List<String> allowedEmployeeIds,
    required bool allChannels,
    required List<String> allowedChannelIds,
  }) async {
    await _api.patch(ApiConstants.saAdminScope(adminId), data: {
      'allEmployees': allEmployees,
      'allowedEmployees': allowedEmployeeIds,
      'allChannels': allChannels,
      'allowedChannels': allowedChannelIds,
    });
  }

  Future<List<PickerEmployee>> getAllEmployeesForPicker() async {
    final res = await _api.get(ApiConstants.saAllEmployeesPicker);
    final list = res['users'];
    if (list is List) {
      return list.map((u) => PickerEmployee.fromJson(Map<String, dynamic>.from(u))).toList();
    }
    return [];
  }

  Future<List<PickerChannel>> getAllChannelsForPicker() async {
    final res = await _api.get(ApiConstants.saAllChannelsPicker);
    final list = res['channels'];
    if (list is List) {
      return list.map((c) => PickerChannel.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }
}
