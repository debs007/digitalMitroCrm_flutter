import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../models/lead_model.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/leads/leads_list_screen.dart';
import '../screens/concern/concern_screen.dart';
import '../screens/salary/salary_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/employees/employees_screen.dart';
import '../screens/admins/manage_admins_screen.dart';
import '../providers/nav_provider.dart';
import '../screens/auth/login_screen.dart';
import 'app_avatar.dart';

class _DrawerItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  _DrawerItem({required this.label, required this.icon, required this.onTap, this.danger = false});
}

/// Side drawer — profile card on top, then a role-adaptive nav list.
/// Admin/SuperAdmin see the full set (Salary, Concern, Manage Admins for
/// SuperAdmin); Employees see a trimmed set; Clients see the least.
///
/// Note: AppDrawer is rendered as the `drawer:` of AppShell's own Scaffold,
/// so — unlike screens pushed via Navigator — it IS inside AppShell's
/// NavProvider scope. That's why "Attendance" and "Tasks" below switch the
/// bottom-nav tab instead of pushing a duplicate screen.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _switchTab(BuildContext context, int index) {
    Navigator.of(context).pop();
    context.read<NavProvider>().setIndex(index);
  }

  Future<void> _logout(BuildContext context) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        // pushAndRemoveUntil(... (route) => false) clears the ENTIRE stack
        // including AppShell, and mounts a brand new LoginScreen instance —
        // popUntil(isFirst) only returned to AppShell since Splash used
        // pushReplacement and isn't in the stack to pop back to.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  List<_DrawerItem> _buildItems(BuildContext context, AppUser? user) {
    final items = <_DrawerItem>[
      _DrawerItem(label: 'Home', icon: Icons.home_outlined, onTap: () => Navigator.of(context).pop()),
    ];

    if (user == null) return items;

    if (user.isClient) {
      // Clients see a minimal set.
      items.addAll([
        _DrawerItem(label: 'Tasks', icon: Icons.task_outlined, onTap: () => _switchTab(context, 1)),
        _DrawerItem(label: 'Settings', icon: Icons.settings_outlined, onTap: () => _push(context, const SettingsScreen())),
      ]);
    } else if (user.isEmployee) {
      items.addAll([
        _DrawerItem(label: 'Attendance', icon: Icons.calendar_today_outlined, onTap: () => _switchTab(context, 2)),
        _DrawerItem(label: 'Notes', icon: Icons.notes_outlined, onTap: () => _push(context, const NotesScreen())),
        _DrawerItem(label: 'Callbacks', icon: Icons.call_outlined, onTap: () => _push(context, const LeadsListScreen(type: LeadType.callback))),
        _DrawerItem(label: 'Transfers', icon: Icons.swap_horiz_outlined, onTap: () => _push(context, const LeadsListScreen(type: LeadType.transfer))),
        _DrawerItem(label: 'Sales', icon: Icons.show_chart_outlined, onTap: () => _push(context, const LeadsListScreen(type: LeadType.sale))),
        _DrawerItem(label: 'Tasks', icon: Icons.task_outlined, onTap: () => _switchTab(context, 1)),
        _DrawerItem(label: 'Concern', icon: Icons.report_gmailerrorred_outlined, onTap: () => _push(context, const ConcernScreen())),
        _DrawerItem(label: 'Salary', icon: Icons.payments_outlined, onTap: () => _push(context, const SalaryScreen())),
        _DrawerItem(label: 'Settings', icon: Icons.settings_outlined, onTap: () => _push(context, const SettingsScreen())),
      ]);
    } else {
      // Admin / SuperAdmin — gated by permission, same pattern as the web sidebar.
      if (user.isSuperAdmin || user.can('attendance', 'access')) {
        items.add(_DrawerItem(label: 'Attendance', icon: Icons.calendar_today_outlined, onTap: () => _switchTab(context, 2)));
      }
      if (user.isSuperAdmin || user.can('notes', 'access')) {
        items.add(_DrawerItem(label: 'Notes', icon: Icons.notes_outlined, onTap: () => _push(context, const NotesScreen())));
      }
      if (user.isSuperAdmin || user.can('callbacks', 'access')) {
        items.add(_DrawerItem(label: 'Callbacks', icon: Icons.call_outlined, onTap: () => _push(context, const LeadsListScreen(type: LeadType.callback))));
      }
      if (user.isSuperAdmin || user.can('transfer', 'access')) {
        items.add(_DrawerItem(label: 'Transfers', icon: Icons.swap_horiz_outlined, onTap: () => _push(context, const LeadsListScreen(type: LeadType.transfer))));
      }
      if (user.isSuperAdmin || user.can('sales', 'access')) {
        items.add(_DrawerItem(label: 'Sales', icon: Icons.show_chart_outlined, onTap: () => _push(context, const LeadsListScreen(type: LeadType.sale))));
      }
      if (user.isSuperAdmin || user.can('activity', 'access')) {
        items.add(_DrawerItem(label: 'Activity', icon: Icons.bar_chart_outlined, onTap: () => _push(context, const EmployeesScreen())));
      }
      if (user.isSuperAdmin || user.can('concern', 'access')) {
        items.add(_DrawerItem(label: 'Concern', icon: Icons.report_gmailerrorred_outlined, onTap: () => _push(context, const ConcernScreen())));
      }
      items.add(_DrawerItem(label: 'Tasks', icon: Icons.task_outlined, onTap: () => _switchTab(context, 1)));
      if (user.isSuperAdmin || user.can('salary', 'access')) {
        items.add(_DrawerItem(label: 'Salary', icon: Icons.payments_outlined, onTap: () => _push(context, const SalaryScreen())));
      }
      if (user.isSuperAdmin) {
        items.add(_DrawerItem(label: 'Manage Admins', icon: Icons.admin_panel_settings_outlined, onTap: () => _push(context, const ManageAdminsScreen())));
      }
      items.add(_DrawerItem(label: 'Settings', icon: Icons.settings_outlined, onTap: () => _push(context, const SettingsScreen())));
    }

    return items;
  }

  String _roleLabel(AppUser user) {
    if (user.isSuperAdmin) return 'Super Admin';
    if (user.isAdmin) return 'Admin';
    if (user.isClient) return 'Client';
    return 'Employee';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final items = _buildItems(context, user);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  AppAvatar(name: user?.name ?? '', imageUrl: user?.avatar, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Guest',
                          style: AppText.h3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user != null ? _roleLabel(user) : '',
                          style: AppText.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textFaint),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: Icon(item.icon, color: item.danger ? AppColors.danger : AppColors.textSecondary),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.danger ? AppColors.danger : AppColors.textPrimary,
                      ),
                    ),
                    onTap: item.onTap,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'Logout',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
