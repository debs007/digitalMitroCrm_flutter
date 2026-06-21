import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<NotificationModel>> getNotifications() async {
    final res = await _api.get(ApiConstants.getNotifications);
    final list = res['notifications'] ?? res['data'];
    if (list is List) {
      return list.map((n) => NotificationModel.fromJson(Map<String, dynamic>.from(n))).toList();
    }
    return [];
  }

  Future<void> clearAll() async {
    await _api.delete(ApiConstants.clearNotifications);
  }
}
