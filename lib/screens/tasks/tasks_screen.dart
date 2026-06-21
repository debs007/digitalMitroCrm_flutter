import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/task_model.dart';
import '../../models/channel_model.dart';
import '../../providers/nav_provider.dart';
import '../../services/chat_list_service.dart';
import '../../services/task_service.dart';
import 'create_task_screen.dart';
import '../../widgets/app_avatar.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _startCreateTask() async {
    List<ChannelModel> channels;
    try {
      channels = await ChatListService.instance.getChannels();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load channels.')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (channels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're not in any channels yet.")),
      );
      return;
    }

    final selected = await showModalBottomSheet<ChannelModel>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Create task in which channel?', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...channels.map((c) => ListTile(
                  leading: const Icon(Icons.tag, color: AppColors.primary),
                  title: Text(c.name),
                  onTap: () => Navigator.pop(ctx, c),
                )),
          ],
        ),
      ),
    );
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
        onPressed: _startCreateTask,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => context.read<NavProvider>().openDrawer(),
        ),
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
                            color: AppColors.primary,
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isBusy
              ? const Padding(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : Checkbox(
                  value: task.isDone,
                  onChanged: (_) => _toggleComplete(task),
                ),
          const SizedBox(width: 4),
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
                    if (_channelNameFor(task.channelId).isNotEmpty)
                      Text('#${_channelNameFor(task.channelId)}', style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
          if (task.assignedToUser != null) ...[
            const SizedBox(width: 8),
            AppAvatar(name: task.assignedToUser!.name, imageUrl: task.assignedToUser!.avatar, size: 30),
          ],
        ],
      ),
    );
  }
}
