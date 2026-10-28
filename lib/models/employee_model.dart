/// GET /auth/ (employee directory, admin-only) returns a raw array of
/// these — note: NOT wrapped in {success, data}, the backend just does
/// res.json(usersWithCounts) directly.
class EmployeeModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final String shiftType; // "Day" | "Night"
  final String employeeType; // "Full-Time" | "Part-Time"
  final String jobDescription;
  final int callbackCount;
  final int saleCount;
  final int transferCount;
  final bool isDeleted;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.shiftType,
    required this.employeeType,
    this.jobDescription = '',
    required this.callbackCount,
    required this.saleCount,
    required this.transferCount,
    required this.isDeleted,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      shiftType: json['type']?.toString() ?? 'Day',
      employeeType: json['employeeType']?.toString() ?? 'Full-Time',
      jobDescription: json['jobDescription']?.toString() ?? '',
      callbackCount: (json['callBackCount'] is num) ? (json['callBackCount'] as num).toInt() : 0,
      saleCount: (json['saleCount'] is num) ? (json['saleCount'] as num).toInt() : 0,
      transferCount: (json['transferCount'] is num) ? (json['transferCount'] as num).toInt() : 0,
      isDeleted: json['isDeleted'] == true,
    );
  }

  /// Merges in just the fields the edit form can change, leaving
  /// aggregate/derived fields (avatar, counts, isDeleted) untouched — the
  /// PUT /auth/:id response doesn't carry those (they're only computed by
  /// the list endpoint), so blindly replacing the whole model with it
  /// would zero them out.
  EmployeeModel copyWithEditableFields(EmployeeModel updated) {
    return EmployeeModel(
      id: id,
      name: updated.name,
      email: updated.email,
      phone: updated.phone,
      avatar: avatar,
      shiftType: updated.shiftType,
      employeeType: updated.employeeType,
      jobDescription: updated.jobDescription,
      callbackCount: callbackCount,
      saleCount: saleCount,
      transferCount: transferCount,
      isDeleted: isDeleted,
    );
  }
}
