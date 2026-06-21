import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  AttendanceService._();
  static final AttendanceService instance = AttendanceService._();

  final ApiClient _api = ApiClient.instance;

  /// Today's attendance — handles the night-shift fallback server-side
  /// (a 3am clock-out still resolves to last night's record).
  Future<AttendanceRecord?> getToday() async {
    final res = await _api.get(ApiConstants.attendanceUser, queryParameters: {'range': 'today'});
    final list = res['data'];
    if (list is List && list.isNotEmpty) {
      return AttendanceRecord.fromJson(Map<String, dynamic>.from(list.first));
    }
    return null;
  }

  /// History for a given range. The backend's /attendance/user endpoint
  /// only understands these four exact values — anything else (or a
  /// missing range) returns 400 "Invalid range parameter".
  Future<List<AttendanceRecord>> getHistory({String range = 'this_month'}) async {
    const validRanges = {'today', 'this_month', 'last_month', 'year'};
    final safeRange = validRanges.contains(range) ? range : 'this_month';

    final res = await _api.get(ApiConstants.attendanceUser, queryParameters: {'range': safeRange});
    final list = res['data'];
    if (list is List) {
      return list.map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return [];
  }

  /// Fetches the device's public IP — required by the backend's punch-in
  /// endpoint (it stores `ip` on the attendance record, same as the web app).
  Future<String> _fetchClientIp() async {
    try {
      final dio = Dio();
      final res = await dio.get('https://api.ipify.org/?format=json');
      return res.data['ip']?.toString() ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> punchIn() async {
    final clientIp = await _fetchClientIp();
    await _api.post(ApiConstants.punchIn, data: {'clientIp': clientIp});
  }

  Future<void> punchOut() async {
    await _api.post(ApiConstants.punchOut);
  }

  // ── Admin/SuperAdmin only ──────────────────────────────────────────────

  /// All employees' attendance for [date] (defaults to today), with
  /// Week-Off/Absent gap-filling already applied server-side. This is the
  /// same scope-filtered endpoint the web admin dashboard uses.
  Future<List<AttendanceRecord>> getAllForDate({DateTime? date}) async {
    final query = <String, dynamic>{};
    if (date != null) {
      query['date'] = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    final res = await _api.get(ApiConstants.attendanceToday, queryParameters: query);
    final list = res['data'];
    if (list is List) {
      return list.map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return [];
  }

  /// A specific employee's attendance history — used from the Activity →
  /// Employee Detail screen. Supports the same month/date/range params as
  /// the web admin's individual employee attendance view.
  Future<List<AttendanceRecord>> getForEmployee({
    required String employeeId,
    String? startDate,
    String? endDate,
    int? month,
    int? year,
  }) async {
    final query = <String, dynamic>{};
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;

    final res = await _api.get(ApiConstants.attendanceListForAdmin(employeeId), queryParameters: query);
    final list = res['data'];
    if (list is List) {
      return list.map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return [];
  }
}
