/// Mirrors the Admin model's `permissions` object exactly (see
/// CRMBackend/models/Admin.js). Each entry defaults to false for a
/// freshly created admin until the SuperAdmin grants access.
class AdminPermissions {
  final Map<String, Map<String, bool>> groups;

  AdminPermissions(this.groups);

  static const List<String> sidebarKeys = [
    'notes', 'callbacks', 'attendance', 'transfer', 'sales',
    'activity', 'concern', 'notification', 'tasks', 'salary',
  ];

  static const Map<String, List<String>> actionGroups = {
    'task': ['create', 'delete'],
    'channel': ['create', 'delete', 'edit'],
    'salarySheet': ['upload', 'revoke'],
    'payslip': ['upload', 'revoke'],
    'report': ['add', 'delete'],
    'taskManagement': ['access'],
    'employee': ['create', 'edit', 'delete'],
  };

  bool get(String group, String action) => groups[group]?[action] ?? false;

  static AdminPermissions empty() {
    final groups = <String, Map<String, bool>>{};
    for (final key in sidebarKeys) {
      groups[key] = {'access': false};
    }
    actionGroups.forEach((group, actions) {
      groups[group] = {for (final a in actions) a: false};
    });
    return AdminPermissions(groups);
  }

  static AdminPermissions allGranted() {
    final p = empty();
    final groups = <String, Map<String, bool>>{};
    p.groups.forEach((g, actions) {
      groups[g] = {for (final a in actions.keys) a: true};
    });
    return AdminPermissions(groups);
  }

  factory AdminPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return AdminPermissions.empty();
    final groups = <String, Map<String, bool>>{};
    json.forEach((group, actions) {
      if (actions is Map) {
        groups[group] = actions.map((k, v) => MapEntry(k.toString(), v == true));
      }
    });
    // Fill in any missing keys with false so the UI always has something to render.
    final defaults = AdminPermissions.empty();
    defaults.groups.forEach((g, actions) {
      groups.putIfAbsent(g, () => actions);
    });
    return AdminPermissions(groups);
  }

  Map<String, dynamic> toJson() => groups;

  AdminPermissions copyWith(String group, String action, bool value) {
    final newGroups = Map<String, Map<String, bool>>.from(
      groups.map((k, v) => MapEntry(k, Map<String, bool>.from(v))),
    );
    newGroups.putIfAbsent(group, () => {});
    newGroups[group]![action] = value;
    return AdminPermissions(newGroups);
  }
}

class AdminModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // "admin" | "superadmin"
  final AdminPermissions permissions;
  final bool allEmployees;
  final List<String> allowedEmployeeIds;
  final bool allChannels;
  final List<String> allowedChannelIds;
  final DateTime createdAt;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.permissions,
    required this.allEmployees,
    required this.allowedEmployeeIds,
    required this.allChannels,
    required this.allowedChannelIds,
    required this.createdAt,
  });

  bool get isSuperAdmin => role == 'superadmin';

  static List<String> _idList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e is Map ? (e['_id']?.toString() ?? '') : e.toString()).where((s) => s.isNotEmpty).toList();
  }

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return AdminModel(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'admin',
      permissions: AdminPermissions.fromJson(
        json['permissions'] is Map ? Map<String, dynamic>.from(json['permissions']) : null,
      ),
      allEmployees: json['allEmployees'] != false,
      allowedEmployeeIds: _idList(json['allowedEmployees']),
      allChannels: json['allChannels'] != false,
      allowedChannelIds: _idList(json['allowedChannels']),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
