import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/task_model.dart';
import '../../models/channel_model.dart';
import '../../services/chat_list_service.dart';
import '../../services/task_service.dart';
import 'create_task_screen.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/channel_logo.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

enum _TaskFilter { all, today, pending, done }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _isLoading = true;
  String? _error;
  List<TaskGroup> _groups = [];
  _TaskFilter _filter = _TaskFilter.all;
  final _searchController = TextEditingController();
  String _busyTaskId = '';
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
    _searchController.dispose();
    if (_onSoftRefresh != null) SocketService.instance.off('soft-refresh', _onSoftRefresh);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await TaskService.instance.getAllTasks(search: _searchController.text.trim());
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load tasks.';
        _isLoading = false;
      });
    }
  }

  List<TaskModel> get _flatTasks {
    final all = _groups.expand((g) => g.tasks).toList();
    final now = DateTime.now();

    switch (_filter) {
      case _TaskFilter.all:
        return all;
      case _TaskFilter.today:
        return all
            .where((t) =>
                t.deadline.year == now.year && t.deadline.month == now.month && t.deadline.day == now.day)
            .toList();
      case _TaskFilter.pending:
        return all.where((t) => !t.isDone).toList();
      case _TaskFilter.done:
        return all.where((t) => t.isDone).toList();
    }
  }

  String _channelNameFor(String channelId) {
    return _groups.firstWhere(
      (g) => g.channelId == channelId,
      orElse: () => TaskGroup(channelId: channelId, channelName: '', tasks: []),
    ).channelName;
  }

  Future<void> _toggleComplete(TaskModel task) async {
    setState(() => _busyTaskId = task.id);
    try {
      await TaskService.instance.updateTaskStatus(
        channelId: task.channelId,
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
      if (mounted) setState(() => _busyTaskId = '');
    }
  }

  String _dueLabel(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(deadline.year, deadline.month, deadline.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 0) return 'Overdue';
    return 'Due ${DateFormat('d MMM').format(deadline)}';
  }

  Color _dueColor(DateTime deadline, bool isDone) {
    if (isDone) return AppColors.success;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(deadline.year, deadline.month, deadline.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return AppColors.danger;
    if (diff == 0) return AppColors.danger;
    if (diff == 1) return AppColors.warning;
    return AppColors.textSecondary;
  }

  bool _creatingTaskFlow = false;

  Future<void> _startCreateTask() async {
    if (_creatingTaskFlow) return; // Guards against double/triple-tap while the fetch is in flight.
    setState(() => _creatingTaskFlow = true);

    List<ChannelModel> channels;
    try {
      channels = await ChatListService.instance.getChannels();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load channels.')),
        );
      }
      if (mounted) setState(() => _creatingTaskFlow = false);
      return;
    }
    if (!mounted) return;
    if (channels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're not in any channels yet.")),
      );
      setState(() => _creatingTaskFlow = false);
      return;
    }

    final selected = await showModalBottomSheet<ChannelModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          var filtered = channels;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Create task in which channel?', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: 'Search channels...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (query) {
                        setSheetState(() {
                          filtered = query.trim().isEmpty
                              ? channels
                              : channels.where((c) => c.name.toLowerCase().contains(query.trim().toLowerCase())).toList();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text('No channels found.', style: TextStyle(color: AppColors.textFaint)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final c = filtered[index];
                                return ListTile(
                                  leading: ChannelLogo(imageUrl: c.image, size: 40),
                                  title: Text(c.name),
                                  onTap: () => Navigator.pop(ctx, c),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (mounted) setState(() => _creatingTaskFlow = false);
    if (selected == null || !mounted) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateTaskScreen(channelId: selected.id, channelName: selected.name)),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _flatTasks;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _creatingTaskFlow ? null : _startCreateTask,
        backgroundColor: AppColors.primary,
        child: _creatingTaskFlow
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        title: const Text('Tasks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, size: 18),
                  onPressed: _load,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', _TaskFilter.all),
                const SizedBox(width: 8),
                _filterChip('Today', _TaskFilter.today),
                const SizedBox(width: 8),
                _filterChip('Pending', _TaskFilter.pending),
                const SizedBox(width: 8),
                _filterChip('Done', _TaskFilter.done),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : tasks.isEmpty
                        ? const EmptyView(message: 'No tasks here.', icon: Icons.task_alt)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.loader,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildTaskTile(tasks[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _TaskFilter value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(TaskModel task) {
    final isBusy = _busyTaskId == task.id;
    final isExpanded = _expandedTaskId == task.id;
    final channelName = _channelNameFor(task.channelId);

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
                      if (channelName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tag, size: 12, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                channelName,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        task.title,
                        style: AppText.bodyLarge.copyWith(
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? AppColors.textFaint : AppColors.textPrimary,
                        ),
                      ),
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
                if (task.assignedToUser != null) ...[
                  const SizedBox(width: 8),
                  AppAvatar(name: task.assignedToUser!.name, imageUrl: task.assignedToUser!.avatar, size: 30),
                ],
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textFaint),
              ],
            ),
            if (isExpanded) ...[
              const Divider(height: 18),
              if (task.taskNumber.isNotEmpty) _detailRow('Task #', task.taskNumber),
              _detailRow('Deadline', DateFormat('d MMM yyyy, hh:mm a').format(task.deadline)),
              if (task.createdByUser != null) _detailRow('Created by', task.createdByUser!.name),
              if (task.assignedToUser != null) _detailRow('Assigned to', task.assignedToUser!.name),
              if (task.completedAt != null) _detailRow('Completed', DateFormat('d MMM yyyy, hh:mm a').format(task.completedAt!)),
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
