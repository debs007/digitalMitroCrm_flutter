import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/socket_service.dart';
import '../../core/utils/ist_time.dart';
import '../../models/channel_model.dart';
import '../../models/dashboard_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../services/attendance_service.dart';
import '../../services/chat_list_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/task_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/channel_logo.dart';
import '../../widgets/state_views.dart';
import '../../widgets/stat_card.dart';
import '../chat/dm_chat_screen.dart';
import '../chat/group_chat_screen.dart';
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

  List<ChannelModel> _channels = [];
  List<DmConversation> _conversations = [];

  void Function(dynamic)? _onNewMessage;
  void Function(dynamic)? _onNewChannelMessage;
  void Function(dynamic)? _onUpdateUnread;
  void Function(dynamic)? _onSoftRefresh;
  void Function(dynamic)? _onReceiveNotification;

  @override
  void initState() {
    super.initState();
    _load();
    _registerSocketListeners();
  }

  @override
  void dispose() {
    final socket = SocketService.instance;
    if (_onNewMessage != null) socket.off('new-message', _onNewMessage);
    if (_onNewChannelMessage != null) socket.off('new-channel-message', _onNewChannelMessage);
    if (_onUpdateUnread != null) socket.off('updateUnread', _onUpdateUnread);
    if (_onSoftRefresh != null) socket.off('soft-refresh', _onSoftRefresh);
    if (_onReceiveNotification != null) socket.off('receive-notification', _onReceiveNotification);
    super.dispose();
  }

  void _registerSocketListeners() {
    final socket = SocketService.instance;

    _onNewMessage = (_) => _load();
    socket.on('new-message', _onNewMessage!);

    _onNewChannelMessage = (_) => _load();
    socket.on('new-channel-message', _onNewChannelMessage!);

    _onUpdateUnread = (_) => _load();
    socket.on('updateUnread', _onUpdateUnread!);

    _onSoftRefresh = (data) {
      if (data is! Map) return;
      final type = data['type']?.toString();
      if (type == 'TASK' || type == 'Attendence') _load();
    };
    socket.on('soft-refresh', _onSoftRefresh!);

    _onReceiveNotification = (_) => _load();
    socket.on('receive-notification', _onReceiveNotification!);
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    try {
      final results = await Future.wait([
        DashboardService.instance.getDashboard(),
        TaskService.instance.getPendingCount(),
        ChatListService.instance.getChannels(),
        ChatListService.instance.getConversations(),
        if (isAdmin) AttendanceService.instance.getAllForDate(),
      ]);
      setState(() {
        _dashboard       = results[0] as DashboardData;
        _pendingTaskCount = results[1] as int;
        _channels        = results[2] as List<ChannelModel>;
        _conversations   = results[3] as List<DmConversation>;
        if (isAdmin && results.length > 4) {
          final teamAttendance = (results[4] as List).cast<AttendanceRecord>();
          _teamTotalCount   = teamAttendance.length;
          _teamPresentCount = teamAttendance.where((r) => r.punchIn != null && !r.isSynthetic).length;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error     = e is ApiException ? e.message : 'Could not load your dashboard.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePunch() async {
    final attendance  = _dashboard?.todayAttendance;
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

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Channels sorted so unread come first, then by most recent message.
  List<ChannelModel> get _sortedChannels {
    final sorted = [..._channels];
    sorted.sort((a, b) {
      // Unread channels bubble to the top.
      final aUnread = a.unreadCount > 0 ? 0 : 1;
      final bUnread = b.unreadCount > 0 ? 0 : 1;
      if (aUnread != bUnread) return aUnread.compareTo(bUnread);
      // Within the same unread group, most-recent message first.
      final aTime = a.lastMessageAt ?? DateTime(2000);
      final bTime = b.lastMessageAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted.take(5).toList();
  }

  List<DmConversation> get _sortedConversations {
    final sorted = [..._conversations];
    sorted.sort((a, b) {
      final aUnread = a.unreadCount > 0 ? 0 : 1;
      final bUnread = b.unreadCount > 0 ? 0 : 1;
      if (aUnread != bUnread) return aUnread.compareTo(bUnread);
      final aTime = a.lastMessageAt ?? DateTime(2000);
      final bTime = b.lastMessageAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted.take(5).toList();
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && now.day == dt.day) return DateFormat('hh:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
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
                    decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
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
                  color: AppColors.loader,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}! 👋', style: AppText.h2),
                        const SizedBox(height: 4),
                        Text("Here's what's happening today.", style: AppText.bodyMuted),
                        const SizedBox(height: 20),

                        // Punch in/out card — employees only
                        if (!(user?.isAdmin ?? false)) ...[
                          _buildPunchCard(),
                          const SizedBox(height: 20),
                        ],

                        // Stat cards
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
                              subtitle: 'Pending',
                              icon: Icons.checklist_rtl,
                              iconColor: AppColors.loader,
                              iconBg: AppColors.primaryTint,
                              onTap: () => context.read<NavProvider>().setIndex(1),
                            ),
                            StatCard(
                              title: (user?.isAdmin ?? false) ? 'Team Present' : 'Attendance',
                              value: (user?.isAdmin ?? false)
                                  ? '$_teamPresentCount/$_teamTotalCount'
                                  : (_dashboard?.todayAttendance?.workStatus ?? '—'),
                              subtitle: (user?.isAdmin ?? false) ? 'Today' : (_dashboard?.todayAttendance?.isInProgress == true ? 'In progress' : 'Today'),
                              icon: Icons.calendar_today_outlined,
                              iconColor: AppColors.info,
                              iconBg: AppColors.infoBg,
                              onTap: () => context.read<NavProvider>().setIndex(2),
                            ),
                            StatCard(
                              title: 'Messages',
                              value: _dashboard?.unreadDMs.toString() ?? '0',
                              subtitle: 'Unread',
                              icon: Icons.chat_bubble_outline,
                              iconColor: AppColors.success,
                              iconBg: AppColors.successBg,
                              onTap: () => context.read<NavProvider>().setIndex(3),
                            ),
                            StatCard(
                              title: 'Notifications',
                              value: (_dashboard?.notifications.length ?? 0).toString(),
                              subtitle: 'Recent',
                              icon: Icons.notifications_outlined,
                              iconColor: AppColors.warning,
                              iconBg: AppColors.warningBg,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Channels ─────────────────────────────────────────
                        _buildSectionHeader(
                          'Channels',
                          onTap: () => context.read<NavProvider>().setIndex(3),
                        ),
                        const SizedBox(height: 10),
                        _sortedChannels.isEmpty
                            ? _emptyRow('No channel messages yet.')
                            : Column(
                                children: _sortedChannels.map(_buildChannelTile).toList(),
                              ),
                        const SizedBox(height: 24),

                        // ── Direct Messages ───────────────────────────────────
                        _buildSectionHeader(
                          'Direct Messages',
                          onTap: () => context.read<NavProvider>().setIndex(3),
                        ),
                        const SizedBox(height: 10),
                        _sortedConversations.isEmpty
                            ? _emptyRow('No direct messages yet.')
                            : Column(
                                children: _sortedConversations.map(_buildDmTile).toList(),
                              ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.h3),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
          child: Text('See all', style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _emptyRow(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text(message, style: AppText.bodyMuted),
    );
  }

  // ─── Channel tile ────────────────────────────────────────────────────────────

  Widget _buildChannelTile(ChannelModel channel) {
    final hasUnread = channel.unreadCount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            channelId: channel.id,
            channelName: channel.name,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread ? AppColors.primaryLight : AppColors.divider,
            width: hasUnread ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ChannelLogo(imageUrl: channel.image, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '# ${channel.name}',
                    style: AppText.bodyLarge.copyWith(
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.lastMessageText != null && channel.lastMessageText!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel.lastMessageText!,
                      style: AppText.caption.copyWith(
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(channel.lastMessageAt),
                  style: AppText.caption.copyWith(
                    color: hasUnread ? AppColors.primary : AppColors.textFaint,
                    fontSize: 10,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      channel.unreadCount > 99 ? '99+' : channel.unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── DM tile ─────────────────────────────────────────────────────────────────

  Widget _buildDmTile(DmConversation conv) {
    final hasUnread = conv.unreadCount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DmChatScreen(
            partnerId: conv.partner.id,
            partnerName: conv.partner.name,
            partnerAvatar: conv.partner.avatar,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread ? AppColors.primaryLight : AppColors.divider,
            width: hasUnread ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AppAvatar(name: conv.partner.name, imageUrl: conv.partner.avatar, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.partner.name,
                    style: AppText.bodyLarge.copyWith(
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conv.lastMessageText != null && conv.lastMessageText!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      conv.lastMessageText!,
                      style: AppText.caption.copyWith(
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(conv.lastMessageAt),
                  style: AppText.caption.copyWith(
                    color: hasUnread ? AppColors.primary : AppColors.textFaint,
                    fontSize: 10,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      conv.unreadCount > 99 ? '99+' : conv.unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Punch card ─────────────────────────────────────────────────────────────

  Widget _buildPunchCard() {
    final attendance  = _dashboard?.todayAttendance;
    final isPunchedIn = attendance?.isPunchedIn ?? false;
    final punchInTime  = attendance?.punchIn  != null ? DateFormat('hh:mm a').format(attendance!.punchIn!.toIst)  : '--:--';
    final punchOutTime = attendance?.punchOut != null ? DateFormat('hh:mm a').format(attendance!.punchOut!.toIst) : '--:--';

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
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.loader))
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
}