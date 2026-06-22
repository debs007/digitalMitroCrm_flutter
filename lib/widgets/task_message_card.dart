import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../models/message_model.dart';

/// Renders a task-related system message as a small card with the task
/// number, title, status/priority chips, deadline, and assignee — instead
/// of a plain grey text bubble. Shown in place of the regular bubble when
/// [ChatMessage.isSystem] is true and [ChatMessage.taskSnapshot] is set.
class TaskMessageCard extends StatelessWidget {
  final ChatMessage message;

  const TaskMessageCard({super.key, required this.message});

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'Acknowledged':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = message.taskSnapshot;
    if (task == null) return const SizedBox.shrink();

    final statusColor = _statusColor(task.status);
    final priorityColor = AppColors.priorityColor(task.priority);

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.task_alt, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    task.taskNumber,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const Spacer(),
                  Text(message.message, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isNotEmpty ? task.title : 'Untitled task',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (task.status.isNotEmpty) _chip(task.status, statusColor),
                      if (task.priority.isNotEmpty) _chip(task.priority, priorityColor),
                    ],
                  ),
                  if (task.deadline != null || task.assignedToName != null) ...[
                    const SizedBox(height: 8),
                    if (task.deadline != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textFaint),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMM, hh:mm a').format(task.deadline!),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    if (task.assignedToName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 12, color: AppColors.textFaint),
                          const SizedBox(width: 4),
                          Text(task.assignedToName!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
