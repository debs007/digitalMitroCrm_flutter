import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/channel_detail_model.dart';
import '../../services/channel_service.dart';
import '../../services/task_service.dart';
import '../../widgets/app_avatar.dart';

class CreateTaskScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const CreateTaskScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _deadline;
  String _priority = 'Medium';
  ChannelMember? _assignee;

  List<ChannelMember> _members = [];
  bool _loadingMembers = true;
  bool _submitting = false;
  String? _error;

  static const _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final detail = await ChannelService.instance.getDetail(widget.channelId);
      setState(() {
        _members = detail.members;
        _loadingMembers = false;
      });
    } catch (_) {
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time?.hour ?? 18, time?.minute ?? 0);
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_deadline == null) {
      setState(() => _error = 'Deadline is required.');
      return;
    }
    if (_assignee == null) {
      setState(() => _error = 'Please assign this task to someone.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await TaskService.instance.createTask(
        channelId: widget.channelId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        deadline: _deadline!,
        assignedTo: _assignee!.id,
        priority: _priority,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not create task.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New task in #${widget.channelName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            const Text('Title', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'e.g. Review landing page copy')),
            const SizedBox(height: 16),

            const Text('Description', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Add more detail (optional)'),
            ),
            const SizedBox(height: 16),

            const Text('Deadline', style: AppText.label),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _deadline == null ? 'Select date & time' : DateFormat('d MMM yyyy, hh:mm a').format(_deadline!),
                      style: AppText.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Priority', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _priorities.map((p) {
                final selected = _priority == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: (_) => setState(() => _priority = p),
                  selectedColor: AppColors.priorityColor(p).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.priorityColor(p) : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Text('Assign to', style: AppText.label),
            const SizedBox(height: 8),
            _loadingMembers
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _members.map((m) {
                      final selected = _assignee?.id == m.id;
                      return GestureDetector(
                        onTap: () => setState(() => _assignee = m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primaryTint : AppColors.neutralBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppAvatar(name: m.name, imageUrl: m.avatar, size: 22),
                              const SizedBox(width: 6),
                              Text(m.name, style: TextStyle(fontSize: 13, color: selected ? AppColors.primary : AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Create Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
