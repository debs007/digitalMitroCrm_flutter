import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../services/attendance_service.dart';
import '../../widgets/state_views.dart';
import 'admin_attendance_view.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  String? _error;
  AttendanceRecord? _today;
  List<AttendanceRecord> _history = [];
  bool _punchLoading = false;

  @override
  void initState() {
    super.initState();
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    if (!isAdmin) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AttendanceService.instance.getToday(),
        AttendanceService.instance.getHistory(),
      ]);
      setState(() {
        _today = results[0] as AttendanceRecord?;
        _history = (results[1] as List<AttendanceRecord>)
          ..sort((a, b) => b.currentDate.compareTo(a.currentDate));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load attendance.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePunch() async {
    final isPunchedIn = _today?.isPunchedIn ?? false;
    setState(() => _punchLoading = true);
    try {
      if (isPunchedIn) {
        await AttendanceService.instance.punchOut();
      } else {
        await AttendanceService.instance.punchIn();
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Punch action failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _punchLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    if (isAdmin) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => context.read<NavProvider>().openDrawer(),
          ),
          title: const Text('Attendance'),
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AdminAttendanceView(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => context.read<NavProvider>().openDrawer(),
        ),
        title: const Text('Attendance'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _timeCard('Check In', _today?.punchIn, Icons.login)),
                          const SizedBox(width: 12),
                          Expanded(child: _timeCard('Check Out', _today?.punchOut, Icons.logout)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Attendance History', style: AppText.h3),
                      const SizedBox(height: 12),
                      if (_history.isEmpty)
                        const EmptyView(message: 'No attendance history yet.', icon: Icons.event_busy)
                      else
                        ..._history.map(_buildHistoryRow),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroCard() {
    final isPunchedIn = _today?.isPunchedIn ?? false;
    final status = _today?.isInProgress == true
        ? 'Work in progress'
        : (_today?.workStatus ?? 'Not marked yet');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _punchLoading ? null : _handlePunch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: _punchLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    )
                  : Text(isPunchedIn ? 'Clock Out' : 'Clock In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeCard(String label, DateTime? time, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: AppText.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time != null ? DateFormat('hh:mm a').format(time) : '--:--',
            style: AppText.h3,
          ),
          Text(
            time != null ? DateFormat('d MMM').format(time) : 'Today',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(AttendanceRecord record) {
    final label = record.isInProgress ? 'Work in progress' : record.workStatus;
    final color = record.isInProgress ? AppColors.warning : AppColors.attendanceColor(record.status);
    final bg = record.isInProgress ? AppColors.warningBg : AppColors.attendanceBg(record.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('d MMMM yyyy').format(record.currentDate), style: AppText.bodyLarge),
                Text(DateFormat('EEEE').format(record.currentDate), style: AppText.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
