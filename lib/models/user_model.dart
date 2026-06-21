import '../core/constants/app_constants.dart';

/// Unified user model. Backed by /mobile/login + /mobile/profile, which
/// always return a flat `user` object regardless of whether the person
/// is an Employee, Admin, SuperAdmin, or Client.
class AppUser {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final String userType; // employee | admin | superadmin | client

  // Employee-only
  final String? phone;
  final String? shiftType; // "Day" | "Night"
  final String? empId;
  final String? employeeType; // "Full-Time" | "Part-Time"

  // Admin/SuperAdmin-only
  final String? role; // "admin" | "superadmin"
  final Map<String, dynamic>? permissions;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.userType,
    this.phone,
    this.shiftType,
    this.empId,
    this.employeeType,
    this.role,
    this.permissions,
  });

  bool get isAdmin => userType == AppConstants.roleAdmin || userType == AppConstants.roleSuperAdmin;
  bool get isSuperAdmin => userType == AppConstants.roleSuperAdmin;
  bool get isEmployee => userType == AppConstants.roleEmployee;
  bool get isClient => userType == AppConstants.roleClient;
  bool get isNightShift => shiftType == 'Night';

  /// Returns true if this user can perform [action] on [resource],
  /// mirroring the web app's permission system. SuperAdmin always true.
  bool can(String resource, String action) {
    if (isSuperAdmin) return true;
    if (!isAdmin) return false; // employees/clients aren't gated by this system
    final res = permissions?[resource];
    if (res is Map) return res[action] == true;
    return false;
  }

  factory AppUser.fromJson(Map<String, dynamic> json, String userType) {
    return AppUser(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      userType: userType,
      phone: json['phone']?.toString(),
      shiftType: json['type']?.toString(),
      empId: json['empId']?.toString(),
      employeeType: json['employeeType']?.toString(),
      role: json['role']?.toString(),
      permissions: json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'phone': phone,
        'type': shiftType,
        'empId': empId,
        'employeeType': employeeType,
        'role': role,
        'permissions': permissions,
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
