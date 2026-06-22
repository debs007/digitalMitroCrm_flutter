import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/socket_service.dart';
import '../../providers/nav_provider.dart';
import '../../services/chat_list_service.dart';
import '../../widgets/app_drawer.dart';
import '../home/home_screen.dart';
import '../tasks/tasks_screen.dart';
import '../attendance/attendance_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_list_screen.dart';

/// Hosts the 5-tab bottom nav (Home, Tasks, Attendance, Notifications, Chat)
/// exactly as shown in the design, plus the side drawer reachable from
/// every tab's hamburger icon.
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
    NotificationsScreen(),
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
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.checklist_outlined), activeIcon: Icon(Icons.checklist), label: 'Tasks'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today_outlined),
        activeIcon: Icon(Icons.calendar_today),
        label: 'Attendance',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.notifications_outlined),
        activeIcon: Icon(Icons.notifications),
        label: 'Notifications',
      ),
      BottomNavigationBarItem(
        icon: Badge(
          isLabelVisible: nav.showChatBadge,
          label: Text(nav.chatUnreadCount > 99 ? '99+' : nav.chatUnreadCount.toString()),
          child: const Icon(Icons.chat_bubble_outline),
        ),
        activeIcon: Badge(
          isLabelVisible: nav.showChatBadge,
          label: Text(nav.chatUnreadCount > 99 ? '99+' : nav.chatUnreadCount.toString()),
          child: const Icon(Icons.chat_bubble),
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
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: nav.currentIndex,
              onTap: nav.setIndex,
              items: _buildItems(nav),
            ),
          );
        },
      ),
    );
  }
}