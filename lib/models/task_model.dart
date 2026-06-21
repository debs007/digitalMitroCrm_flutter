/// A short user reference embedded inside tasks (assignedToUser / createdByUser).
class TaskUserRef {
  final String id;
  final String name;
  final String avatar;

  TaskUserRef({required this.id, required this.name, required this.avatar});

  factory TaskUserRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TaskUserRef(id: '', name: 'Unknown', avatar: '');
    return TaskUserRef(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString() ?? '',
    );
  }
}

/// Mirrors ChannelTask model. Status: Assigned | Acknowledged | Completed.
/// Priority: Low | Medium | High | Urgent.
class TaskModel {
  final String id;
  final String channelId;
  final String taskNumber;
  final String title;
  final String description;
  final DateTime deadline;
  final String status;
  final String priority;
  final List<String> tags;
  final bool isOverdue;
  final DateTime? completedAt;
  final TaskUserRef? assignedToUser;
  final TaskUserRef? createdByUser;

  TaskModel({
    required this.id,
    required this.channelId,
    required this.taskNumber,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
    required this.priority,
    required this.tags,
    required this.isOverdue,
    this.completedAt,
    this.assignedToUser,
    this.createdByUser,
  });

  bool get isDone => status == 'Completed';

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return TaskModel(
      id: (json['_id'] ?? '').toString(),
      channelId: (json['channelId'] ?? '').toString(),
      taskNumber: json['taskNumber']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      deadline: parseDate(json['deadline']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'Assigned',
      priority: json['priority']?.toString() ?? 'Medium',
      tags: (json['tags'] is List) ? List<String>.from(json['tags']) : <String>[],
      isOverdue: json['isOverdue'] == true,
      completedAt: parseDate(json['completedAt']),
      assignedToUser: json['assignedToUser'] is Map
          ? TaskUserRef.fromJson(Map<String, dynamic>.from(json['assignedToUser']))
          : null,
      createdByUser: json['createdByUser'] is Map
          ? TaskUserRef.fromJson(Map<String, dynamic>.from(json['createdByUser']))
          : null,
    );
  }
}

/// /channels/tasks/all groups tasks by channel.
class TaskGroup {
  final String channelId;
  final String channelName;
  final List<TaskModel> tasks;

  TaskGroup({required this.channelId, required this.channelName, required this.tasks});

  factory TaskGroup.fromJson(Map<String, dynamic> json) {
    return TaskGroup(
      channelId: json['channelId']?.toString() ?? '',
      channelName: json['channelName']?.toString() ?? 'Unknown Channel',
      tasks: (json['tasks'] is List)
          ? (json['tasks'] as List)
              .map((t) => TaskModel.fromJson(Map<String, dynamic>.from(t)))
              .toList()
          : <TaskModel>[],
    );
  }
}
