import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/dashboard_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../services/attendance_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/task_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/stat_card.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _error;
  DashboardData? _dashboard;
  int _pendingTaskCount = 0;
  int _teamPresentCount = 0;
  int _teamTotalCount = 0;
  bool _punchActionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    try {
      final results = await Future.wait([
        DashboardService.instance.getDashboard(),
        TaskService.instance.getPendingCount(),
        if (isAdmin) AttendanceService.instance.getAllForDate(),
      ]);
      setState(() {
        _dashboard = results[0] as DashboardData;
        _pendingTaskCount = results[1] as int;
        if (isAdmin && results.length > 2) {
          final teamAttendance = (results[2] as List).cast<AttendanceRecord>();
          _teamTotalCount = teamAttendance.length;
          _teamPresentCount = teamAttendance.where((r) => r.punchIn != null && !r.isSynthetic).length;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load your dashboard.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePunch() async {
    final attendance = _dashboard?.todayAttendance;
    final isPunchedIn = attendance?.isPunchedIn ?? false;

    setState(() => _punchActionLoading = true);
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
      if (mounted) setState(() => _punchActionLoading = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => context.read<NavProvider>().openDrawer(),
        ),
        title: const Text('Digital Mitro'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              if ((_dashboard?.notifications.where((n) => !n.isRead).length ?? 0) > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}! 👋', style: AppText.h2),
                        const SizedBox(height: 4),
                        const Text("Here's what's happening today.", style: AppText.bodyMuted),
                        const SizedBox(height: 20),

                        // Punch in/out card — employees only, admins don't clock in/out
                        if (!(user?.isAdmin ?? false)) ...[
                          _buildPunchCard(),
                          const SizedBox(height: 20),
                        ],

                        // Stat cards grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.15,
                          children: [
                            StatCard(
                              title: 'My Tasks',
                              value: _pendingTaskCount.toString(),
                              subtitle: 'Due today',
                              icon: Icons.checklist_rtl,
                              iconColor: AppColors.primary,
                              iconBg: AppColors.primaryTint,
                            ),
                            StatCard(
                              title: (user?.isAdmin ?? false) ? 'Team Present' : 'Attendance',
                              value: (user?.isAdmin ?? false)
                                  ? '$_teamPresentCount/$_teamTotalCount'
                                  : (_dashboard?.todayAttendance?.workStatus ?? '—'),
                              subtitle: (user?.isAdmin ?? false)
                                  ? 'Today'
                                  : (_dashboard?.todayAttendance?.isInProgress == true ? 'In progress' : 'Today'),
                              icon: Icons.calendar_today_outlined,
                              iconColor: AppColors.info,
                              iconBg: AppColors.infoBg,
                            ),
                            StatCard(
                              title: 'Messages',
                              value: _dashboard?.unreadDMs.toString() ?? '0',
                              subtitle: 'Unread',
                              icon: Icons.chat_bubble_outline,
                              iconColor: AppColors.success,
                              iconBg: AppColors.successBg,
                            ),
                            StatCard(
                              title: 'Notifications',
                              value: _dashboard?.notifications.length.toString() ?? '0',
                              subtitle: 'Recent',
                              icon: Icons.notifications_outlined,
                              iconColor: AppColors.warning,
                              iconBg: AppColors.warningBg,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recent Activity', style: AppText.h3),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              ),
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildRecentActivity(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPunchCard() {
    final attendance = _dashboard?.todayAttendance;
    final isPunchedIn = attendance?.isPunchedIn ?? false;
    final punchInTime = attendance?.punchIn != null ? DateFormat('hh:mm a').format(attendance!.punchIn!) : '--:--';
    final punchOutTime = attendance?.punchOut != null ? DateFormat('hh:mm a').format(attendance!.punchOut!) : '--:--';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPunchedIn ? "You're clocked in" : "You're clocked out",
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMM').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _punchActionLoading ? null : _handlePunch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: _punchActionLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Text(isPunchedIn ? 'Clock Out' : 'Clock In'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _punchTimeTile('Check In', punchInTime)),
              const SizedBox(width: 12),
              Expanded(child: _punchTimeTile('Check Out', punchOutTime)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _punchTimeTile(String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final notifications = _dashboard?.notifications ?? [];
    if (notifications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyView(message: 'No recent activity yet.', icon: Icons.history),
      );
    }

    return Column(
      children: notifications.take(5).map((n) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_none, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title, style: AppText.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(n.description, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(DateFormat('hh:mm a').format(n.createdAt), style: AppText.caption),
            ],
          ),
        );
      }).toList(),
    );
  }
}
