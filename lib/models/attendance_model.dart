/// Mirrors the backend Attendance model (models/Attendance.js) plus the
/// `isSynthetic` flag our gap-filling logic adds for days with no punch.
class AttendanceRecord {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final DateTime currentDate;
  final DateTime? punchIn;
  final DateTime? punchOut;
  final int workingTimeMinutes;
  final String shiftType; // Day | Night
  final String status; // On Time | Late | Holiday | Weekend | Week-Off | Leave | Absent
  final String workStatus; // Half Day | Full Day | Absent | Leave | Week-Off | Holiday | Weekend
  final bool isPunchedIn;
  final bool leaveApproved;
  final bool isSynthetic;

  AttendanceRecord({
    required this.id,
    required this.userId,
    this.userName = '',
    this.userAvatar = '',
    required this.currentDate,
    this.punchIn,
    this.punchOut,
    required this.workingTimeMinutes,
    required this.shiftType,
    required this.status,
    required this.workStatus,
    required this.isPunchedIn,
    required this.leaveApproved,
    this.isSynthetic = false,
  });

  /// True when the employee has punched in but not yet punched out —
  /// shown as "Work in progress" (yellow) on the web app.
  bool get isInProgress => punchIn != null && punchOut == null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    final userIdRaw = json['user_id'];
    String userId = '';
    String userName = '';
    String userAvatar = '';
    if (userIdRaw is Map) {
      userId = userIdRaw['_id']?.toString() ?? '';
      userName = userIdRaw['name']?.toString() ?? '';
      userAvatar = userIdRaw['avatar']?.toString() ?? '';
    } else {
      userId = userIdRaw?.toString() ?? '';
    }

    return AttendanceRecord(
      id: (json['_id'] ?? '').toString(),
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      currentDate: parseDate(json['currentDate']) ?? DateTime.now(),
      punchIn: parseDate(json['punchIn']),
      punchOut: parseDate(json['punchOut']),
      workingTimeMinutes: (json['workingTime'] is num) ? (json['workingTime'] as num).toInt() : 0,
      shiftType: json['shiftType']?.toString() ?? 'Day',
      status: json['status']?.toString() ?? 'Absent',
      workStatus: json['workStatus']?.toString() ?? 'Absent',
      isPunchedIn: json['isPunchedIn'] == true,
      leaveApproved: json['leaveApproved'] == true,
      isSynthetic: json['isSynthetic'] == true,
    );
  }

  String get workingTimeFormatted {
    final h = workingTimeMinutes ~/ 60;
    final m = workingTimeMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}
