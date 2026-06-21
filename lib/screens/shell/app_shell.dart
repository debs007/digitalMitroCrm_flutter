import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/nav_provider.dart';
import '../../widgets/app_drawer.dart';
import '../home/home_screen.dart';
import '../tasks/tasks_screen.dart';
import '../attendance/attendance_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_list_screen.dart';

/// Hosts the 5-tab bottom nav (Home, Tasks, Attendance, Notifications, Chat)
/// exactly as shown in the design, plus the side drawer reachable from
/// every tab's hamburger icon.
class AppShell extends StatelessWidget {
  AppShell({super.key});

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _screens = [
    HomeScreen(),
    TasksScreen(),
    AttendanceScreen(),
    NotificationsScreen(),
    ChatListScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.checklist_outlined), activeIcon: Icon(Icons.checklist), label: 'Tasks'),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today_outlined),
      activeIcon: Icon(Icons.calendar_today),
      label: 'Attendance',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications_outlined),
      activeIcon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      activeIcon: Icon(Icons.chat_bubble),
      label: 'Chat',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavProvider(scaffoldKey: _scaffoldKey),
      child: Consumer<NavProvider>(
        builder: (context, nav, _) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: const AppDrawer(),
            body: IndexedStack(index: nav.currentIndex, children: _screens),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: nav.currentIndex,
              onTap: nav.setIndex,
              items: _items,
            ),
          );
        },
      ),
    );
  }
}
