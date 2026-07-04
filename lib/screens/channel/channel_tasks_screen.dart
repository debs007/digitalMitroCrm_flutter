import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../tasks/create_task_screen.dart';

/// "View Tasks" menu item inside a group chat — shows just this channel's
/// tasks, as opposed to the bottom-nav Tasks tab's grouped-by-channel view.
class ChannelTasksScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelTasksScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelTasksScreen> createState() => _ChannelTasksScreenState();
}

class _ChannelTasksScreenState extends State<ChannelTasksScreen> {
  bool _isLoading = true;
  String? _error;
  List<TaskModel> _tasks = [];
  String? _busyTaskId;
  String? _expandedTaskId;
  void Function(dynamic)? _onSoftRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    final socket = SocketService.instance;
    _onSoftRefresh = (data) {
      if (data is Map && data['type']?.toString() == 'TASK') _load();
    };
    socket.on('soft-refresh', _onSoftRefresh!);
  }

  @override
  void dispose() {
    if (_onSoftRefresh != null) SocketService.instance.off('soft-refresh', _onSoftRefresh);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tasks = await TaskService.instance.getChannelTasks(widget.channelId);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load tasks.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleComplete(TaskModel task) async {
    setState(() => _busyTaskId = task.id);
    try {
      await TaskService.instance.updateTaskStatus(
        channelId: widget.channelId,
        taskId: task.id,
        status: task.isDone ? 'Assigned' : 'Completed',
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not update task.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }

  Future<void> _openCreateTask() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateTaskScreen(channelId: widget.channelId, channelName: widget.channelName)),
    );
    if (created == true) _load();
  }

  Color _dueColor(DateTime deadline, bool isDone) {
    if (isDone) return AppColors.success;
    final now = DateTime.now();
    if (deadline.isBefore(now)) return AppColors.danger;
    if (deadline.difference(now).inHours < 24) return AppColors.warning;
    return AppColors.info;
  }

  String _dueLabel(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) return 'Overdue';
    if (deadline.difference(now).inHours < 24) return 'Due today';
    return DateFormat('d MMM').format(deadline);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tasks in #${widget.channelName}')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTask,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _tasks.isEmpty
                  ? const EmptyView(message: 'No tasks in this channel yet.', icon: Icons.checklist_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.loader,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          final isBusy = _busyTaskId == task.id;
                          final isExpanded = _expandedTaskId == task.id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _expandedTaskId = isExpanded ? null : task.id),
                            child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isExpanded ? AppColors.primary : AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: AppText.bodyLarge.copyWith(
                                              decoration: task.isDone ? TextDecoration.lineThrough : null,
                                              color: task.isDone ? AppColors.textFaint : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (task.assignedToUser != null) ...[
                                            const SizedBox(height: 2),
                                            Text('Assigned to ${task.assignedToUser!.name}', style: AppText.caption),
                                          ],
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              StatusChip(
                                                label: task.isDone ? 'Completed' : _dueLabel(task.deadline),
                                                color: _dueColor(task.deadline, task.isDone),
                                                background: _dueColor(task.deadline, task.isDone).withValues(alpha: 0.12),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.arrow_upward, size: 11, color: AppColors.priorityColor(task.priority)),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    task.priority,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.priorityColor(task.priority),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textFaint),
                                  ],
                                ),
                                if (isExpanded) ...[
                                  const Divider(height: 18),
                                  if (task.taskNumber.isNotEmpty) _detailRow('Task #', task.taskNumber),
                                  _detailRow('Deadline', DateFormat('d MMM yyyy, hh:mm a').format(task.deadline)),
                                  if (task.createdByUser != null) _detailRow('Created by', task.createdByUser!.name),
                                  if (task.completedAt != null)
                                    _detailRow('Completed', DateFormat('d MMM yyyy, hh:mm a').format(task.completedAt!)),
                                  if (task.tags.isNotEmpty) _detailRow('Tags', task.tags.join(', ')),
                                  const SizedBox(height: 4),
                                  Text('Description', style: AppText.label),
                                  const SizedBox(height: 4),
                                  Text(task.description.isNotEmpty ? task.description : 'No description.', style: AppText.body),
                                  if (!task.isDone) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: isBusy ? null : () => _toggleComplete(task),
                                        icon: isBusy
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.loader))
                                            : const Icon(Icons.check_circle_outline, size: 18),
                                        label: Text(isBusy ? 'Updating...' : 'Mark as complete'),
                                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.success, side: BorderSide(color: AppColors.success)),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value, style: AppText.body)),
        ],
      ),
    );
  }
}
