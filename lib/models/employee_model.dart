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
      callbackCount: (json['callBackCount'] is num) ? (json['callBackCount'] as num).toInt() : 0,
      saleCount: (json['saleCount'] is num) ? (json['saleCount'] as num).toInt() : 0,
      transferCount: (json['transferCount'] is num) ? (json['transferCount'] as num).toInt() : 0,
      isDeleted: json['isDeleted'] == true,
    );
  }
}
