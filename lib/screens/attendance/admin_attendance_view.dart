import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/state_views.dart';

/// Shown instead of the employee punch-card view when the logged-in user
/// is an Admin/SuperAdmin — admins don't clock in/out, they review the
/// whole team's attendance for any date.
class AdminAttendanceView extends StatefulWidget {
  const AdminAttendanceView({super.key});

  @override
  State<AdminAttendanceView> createState() => _AdminAttendanceViewState();
}

class _AdminAttendanceViewState extends State<AdminAttendanceView> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;
  List<AttendanceRecord> _records = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final records = await AttendanceService.instance.getAllForDate(date: _selectedDate);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load attendance.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  List<AttendanceRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _records;
    return _records.where((r) => r.userName.toLowerCase().contains(q)).toList();
  }

  Map<String, int> get _summary {
    final present = _records.where((r) => r.punchIn != null && !r.isSynthetic).length;
    final absent = _records.where((r) => r.workStatus == 'Absent').length;
    final onLeave = _records.where((r) => r.workStatus == 'Leave').length;
    final weekOff = _records.where((r) => r.workStatus == 'Week-Off').length;
    return {'present': present, 'absent': absent, 'leave': onLeave, 'weekOff': weekOff};
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Date selector
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isToday ? 'Today' : DateFormat('EEEE').format(_selectedDate),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        DateFormat('d MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: LoadingView())
        else if (_error != null)
          ErrorView(message: _error!, onRetry: _load)
        else ...[
          // Summary chips
          Row(
            children: [
              Expanded(child: _summaryTile('Present', summary['present']!, AppColors.success, AppColors.successBg)),
              const SizedBox(width: 8),
              Expanded(child: _summaryTile('Absent', summary['absent']!, AppColors.danger, AppColors.dangerBg)),
              const SizedBox(width: 8),
              Expanded(child: _summaryTile('Leave', summary['leave']!, AppColors.info, AppColors.infoBg)),
              const SizedBox(width: 8),
              Expanded(child: _summaryTile('Week-Off', summary['weekOff']!, AppColors.textFaint, AppColors.neutralBg)),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search employee...', prefixIcon: Icon(Icons.search, size: 20)),
          ),
          const SizedBox(height: 10),

          if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyView(message: 'No attendance records for this date.', icon: Icons.event_busy),
            )
          else
            ..._filtered.map(_buildRow),
        ],
        ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, int count, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRow(AttendanceRecord r) {
    final label = r.isInProgress ? 'Work in progress' : r.workStatus;
    final color = r.isInProgress ? AppColors.warning : AppColors.attendanceColor(r.status);
    final bg = r.isInProgress ? AppColors.warningBg : AppColors.attendanceBg(r.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AppAvatar(name: r.userName, imageUrl: r.userAvatar, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.userName.isNotEmpty ? r.userName : 'Unknown', style: AppText.bodyLarge),
                if (r.punchIn != null)
                  Text(
                    'In: ${DateFormat('hh:mm a').format(r.punchIn!)}'
                    '${r.punchOut != null ? '  Out: ${DateFormat('hh:mm a').format(r.punchOut!)}' : ''}',
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
