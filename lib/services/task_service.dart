import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/task_model.dart';

class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  final ApiClient _api = ApiClient.instance;

  /// Returns tasks grouped by channel. Employees automatically only see
  /// tasks assigned to them (server-side filter) — admins see everything.
  Future<List<TaskGroup>> getAllTasks({String? search, String? status, String? priority}) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (priority != null && priority.isNotEmpty) query['priority'] = priority;

    final res = await _api.get(ApiConstants.allTasks, queryParameters: query);
    final groups = res['groups'];
    if (groups is List) {
      return groups.map((g) => TaskGroup.fromJson(Map<String, dynamic>.from(g))).toList();
    }
    return [];
  }

  Future<int> getPendingCount() async {
    final res = await _api.get(ApiConstants.pendingTasksCount);
    final count = res['pendingCount'];
    return (count is num) ? count.toInt() : 0;
  }

  Future<void> createTask({
    required String channelId,
    required String title,
    required String description,
    required DateTime deadline,
    required String assignedTo,
    required String priority,
  }) async {
    await _api.post(ApiConstants.channelTasks(channelId), data: {
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'assignedTo': assignedTo,
      'priority': priority,
    });
  }

  /// Marks a task Acknowledged or Completed.
  Future<void> updateTaskStatus({
    required String channelId,
    required String taskId,
    required String status,
  }) async {
    await _api.patch(
      ApiConstants.updateTask(channelId, taskId),
      data: {'status': status},
    );
  }
}
