import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/employee_model.dart';

class EmployeeService {
  EmployeeService._();
  static final EmployeeService instance = EmployeeService._();

  final ApiClient _api = ApiClient.instance;

  /// GET /auth/ returns a raw JSON array directly (not wrapped in
  /// {success, data}) — the backend does res.json(usersWithCounts).
  Future<List<EmployeeModel>> getAll() async {
    final res = await _api.get(ApiConstants.allEmployees);
    // ApiClient normally expects a Map; for a bare array response it wraps
    // it as {'success': true, 'data': [...]}  via its _asMap fallback.
    final list = res['data'];
    if (list is List) {
      return list.map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return [];
  }

  Future<void> create({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String shiftType, // "Day" | "Night"
    String employeeType = 'Full-Time',
  }) async {
    await _api.post(ApiConstants.createEmployee, data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'shift': shiftType,
      'employeeType': employeeType,
    });
  }

  /// Raw counts summary for one employee — GET /attendance/employeesdashboard/:id
  /// returns {attendance, callback, sale, transfer, project} with no wrapper.
  Future<Map<String, int>> getDashboardSummary(String employeeId) async {
    final res = await _api.get(ApiConstants.employeeDashboard(employeeId));
    return {
      'attendance': (res['attendance'] is num) ? (res['attendance'] as num).toInt() : 0,
      'callback': (res['callback'] is num) ? (res['callback'] as num).toInt() : 0,
      'sale': (res['sale'] is num) ? (res['sale'] as num).toInt() : 0,
      'transfer': (res['transfer'] is num) ? (res['transfer'] as num).toInt() : 0,
    };
  }

  Future<void> update({
    required String id,
    String? name,
    String? email,
    String? phone,
    String? shiftType,
    String? employeeType,
  }) async {
    await _api.put(ApiConstants.employeeById(id), data: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (shiftType != null) 'shift': shiftType,
      if (employeeType != null) 'employeeType': employeeType,
    });
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConstants.employeeById(id));
  }
}
