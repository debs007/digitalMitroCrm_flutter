import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/nav_provider.dart';
import '../../services/chat_list_service.dart';
import '../../widgets/app_drawer.dart';
import '../home/home_screen.dart';
import '../tasks/tasks_screen.dart';
import '../attendance/attendance_screen.dart';
import '../chat/chat_list_screen.dart';

/// Hosts the 4-tab bottom nav (Home, Tasks, Attendance, Chat) plus the side
/// drawer reachable from every tab's hamburger icon. Notifications is
/// reachable from the bell icon on Home and the Notifications stat tile
/// rather than taking up a 5th bottom-nav slot.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final NavProvider _nav;

  void Function(dynamic)? _onNewMessage;
  void Function(dynamic)? _onNewChannelMessage;
  void Function(dynamic)? _onUpdateUnread;

  static const _screens = [
    HomeScreen(),
    TasksScreen(),
    AttendanceScreen(),
    ChatListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _nav = NavProvider(scaffoldKey: _scaffoldKey);
    _refreshChatBadge();
    _registerSocketListeners();
  }

  @override
  void dispose() {
    final socket = SocketService.instance;
    if (_onNewMessage != null) socket.off('new-message', _onNewMessage);
    if (_onNewChannelMessage != null) socket.off('new-channel-message', _onNewChannelMessage);
    if (_onUpdateUnread != null) socket.off('updateUnread', _onUpdateUnread);
    _nav.dispose();
    super.dispose();
  }

  void _registerSocketListeners() {
    final socket = SocketService.instance;

    _onNewMessage = (_) => _refreshChatBadge();
    socket.on('new-message', _onNewMessage!);

    _onNewChannelMessage = (_) => _refreshChatBadge();
    socket.on('new-channel-message', _onNewChannelMessage!);

    _onUpdateUnread = (_) => _refreshChatBadge();
    socket.on('updateUnread', _onUpdateUnread!);
  }

  Future<void> _refreshChatBadge() async {
    try {
      final total = await ChatListService.instance.getTotalUnreadCount();
      if (mounted) _nav.setChatUnreadCount(total);
    } catch (_) {
      // Non-fatal — badge just won't update this cycle.
    }
  }

  List<BottomNavigationBarItem> _buildItems(NavProvider nav) {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined, size: 24),
        activeIcon: Icon(Icons.home_rounded, size: 26),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.fact_check_outlined, size: 24),
        activeIcon: Icon(Icons.fact_check_rounded, size: 26),
        label: 'Tasks',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.event_available_outlined, size: 24),
        activeIcon: Icon(Icons.event_available_rounded, size: 26),
        label: 'Attendance',
      ),
      BottomNavigationBarItem(
        icon: Badge(
          isLabelVisible: nav.showChatBadge,
          label: Text(nav.chatUnreadCount > 99 ? '99+' : nav.chatUnreadCount.toString()),
          child: const Icon(Icons.forum_outlined, size: 24),
        ),
        activeIcon: Badge(
          isLabelVisible: nav.showChatBadge,
          label: Text(nav.chatUnreadCount > 99 ? '99+' : nav.chatUnreadCount.toString()),
          child: const Icon(Icons.forum_rounded, size: 26),
        ),
        label: 'Chat',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NavProvider>.value(
      value: _nav,
      child: Consumer<NavProvider>(
        builder: (context, nav, _) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: const AppDrawer(),
            body: IndexedStack(index: nav.currentIndex, children: _screens),
            // Custom footer instead of a bare BottomNavigationBar: a
            // hamburger on the left (opens the drawer — reachable from
            // every tab now, not just via an AppBar leading icon) plus
            // the 4 tab destinations taking up the rest of the width.
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.menu_rounded, size: 26, color: AppColors.textSecondary),
                        onPressed: nav.openDrawer,
                        tooltip: 'Menu',
                      ),
                      Container(width: 1, height: 32, color: AppColors.divider),
                      Expanded(
                        child: BottomNavigationBar(
                          currentIndex: nav.currentIndex,
                          onTap: nav.setIndex,
                          items: _buildItems(nav),
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
