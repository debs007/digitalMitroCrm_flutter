import 'attendance_model.dart';
import 'notification_model.dart';

/// Maps GET /mobile/dashboard.
class DashboardData {
  final AttendanceRecord? todayAttendance;
  final int unreadDMs;
  final List<NotificationModel> notifications;
  final String date;

  DashboardData({
    required this.todayAttendance,
    required this.unreadDMs,
    required this.notifications,
    required this.date,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final dashboard = json['dashboard'] is Map
        ? Map<String, dynamic>.from(json['dashboard'])
        : <String, dynamic>{};

    return DashboardData(
      todayAttendance: dashboard['todayAttendance'] is Map
          ? AttendanceRecord.fromJson(Map<String, dynamic>.from(dashboard['todayAttendance']))
          : null,
      unreadDMs: (dashboard['unreadDMs'] is num) ? (dashboard['unreadDMs'] as num).toInt() : 0,
      notifications: (dashboard['notifications'] is List)
          ? (dashboard['notifications'] as List)
              .map((n) => NotificationModel.fromJson(Map<String, dynamic>.from(n)))
              .toList()
          : <NotificationModel>[],
      date: dashboard['date']?.toString() ?? '',
    );
  }
}
