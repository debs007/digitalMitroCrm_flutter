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
import 'app_avatar.dart';

class _DrawerItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  final int? badgeCount;
  final Color color;

  _DrawerItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.badgeCount,
    Color? color,
  }) : color = color ?? AppColors.primary;
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

  List<_DrawerItem> _buildItems(BuildContext context, AppUser? user, NavProvider nav) {
    final items = <_DrawerItem>[
      _DrawerItem(label: 'Home', icon: Icons.home_rounded, color: const Color(0xFF2563EB), onTap: () => _switchTab(context, 0)),
    ];

    if (user == null) return items;

    if (user.isClient) {
      // Clients see a minimal set.
      items.addAll([
        _DrawerItem(label: 'Tasks', icon: Icons.task_rounded, color: const Color(0xFFEA580C), onTap: () => _switchTab(context, 1)),
        _DrawerItem(label: 'Settings', icon: Icons.settings_rounded, color: const Color(0xFF475569), onTap: () => _push(context, const SettingsScreen())),
      ]);
    } else if (user.isEmployee) {
      items.addAll([
        _DrawerItem(label: 'Attendance', icon: Icons.event_available_rounded, color: const Color(0xFF0D9488), onTap: () => _switchTab(context, 2)),
        _DrawerItem(label: 'Notes', icon: Icons.sticky_note_2_rounded, color: const Color(0xFFD97706), onTap: () => _push(context, const NotesScreen())),
        _DrawerItem(label: 'Callbacks', icon: Icons.call_rounded, color: const Color(0xFF0284C7), badgeCount: nav.callbackCount, onTap: () => _push(context, const LeadsListScreen(type: LeadType.callback))),
        _DrawerItem(label: 'Transfers', icon: Icons.swap_horiz_rounded, color: const Color(0xFF4F46E5), badgeCount: nav.transferCount, onTap: () => _push(context, const LeadsListScreen(type: LeadType.transfer))),
        _DrawerItem(label: 'Sales', icon: Icons.trending_up_rounded, color: const Color(0xFF16A34A), badgeCount: nav.saleCount, onTap: () => _push(context, const LeadsListScreen(type: LeadType.sale))),
        _DrawerItem(label: 'Tasks', icon: Icons.task_rounded, color: const Color(0xFFEA580C), badgeCount: nav.taskCount, onTap: () => _switchTab(context, 1)),
        _DrawerItem(label: 'Concern', icon: Icons.report_problem_rounded, color: const Color(0xFFDC2626), onTap: () => _push(context, const ConcernScreen())),
        _DrawerItem(label: 'Salary', icon: Icons.payments_rounded, color: const Color(0xFF059669), onTap: () => _push(context, const SalaryScreen())),
        _DrawerItem(label: 'Settings', icon: Icons.settings_rounded, color: const Color(0xFF475569), onTap: () => _push(context, const SettingsScreen())),
      ]);
    } else {
      // Admin / SuperAdmin — gated by permission, same pattern as the web sidebar.
      if (user.isSuperAdmin || user.can('attendance', 'access')) {
        items.add(_DrawerItem(label: 'Attendance', icon: Icons.event_available_rounded, color: const Color(0xFF0D9488), onTap: () => _switchTab(context, 2)));
      }
      if (user.isSuperAdmin || user.can('notes', 'access')) {
        items.add(_DrawerItem(label: 'Notes', icon: Icons.sticky_note_2_rounded, color: const Color(0xFFD97706), onTap: () => _push(context, const NotesScreen())));
      }
      if (user.isSuperAdmin || user.can('callbacks', 'access')) {
        items.add(_DrawerItem(label: 'Callbacks', icon: Icons.call_rounded, color: const Color(0xFF0284C7), badgeCount: nav.callbackCount, onTap: () => _push(context, const LeadsListScreen(type: LeadType.callback))));
      }
      if (user.isSuperAdmin || user.can('transfer', 'access')) {
        items.add(_DrawerItem(label: 'Transfers', icon: Icons.swap_horiz_rounded, color: const Color(0xFF4F46E5), badgeCount: nav.transferCount, onTap: () => _push(context, const LeadsListScreen(type: LeadType.transfer))));
      }
      if (user.isSuperAdmin || user.can('sales', 'access')) {
        items.add(_DrawerItem(label: 'Sales', icon: Icons.trending_up_rounded, color: const Color(0xFF16A34A), badgeCount: nav.saleCount, onTap: () => _push(context, const LeadsListScreen(type: LeadType.sale))));
      }
      if (user.isSuperAdmin || user.can('activity', 'access')) {
        items.add(_DrawerItem(label: 'Activity', icon: Icons.insights_rounded, color: const Color(0xFF0891B2), onTap: () => _push(context, const EmployeesScreen())));
      }
      if (user.isSuperAdmin || user.can('concern', 'access')) {
        items.add(_DrawerItem(label: 'Concern', icon: Icons.report_problem_rounded, color: const Color(0xFFDC2626), badgeCount: nav.concernCount, onTap: () => _push(context, const ConcernScreen())));
      }
      items.add(_DrawerItem(label: 'Tasks', icon: Icons.task_rounded, color: const Color(0xFFEA580C), badgeCount: nav.taskCount, onTap: () => _switchTab(context, 1)));
      if (user.isSuperAdmin || user.can('salary', 'access')) {
        items.add(_DrawerItem(label: 'Salary', icon: Icons.payments_rounded, color: const Color(0xFF059669), onTap: () => _push(context, const SalaryScreen())));
      }
      if (user.isSuperAdmin) {
        items.add(_DrawerItem(label: 'Manage Admins', icon: Icons.admin_panel_settings_rounded, color: const Color(0xFFDB2777), onTap: () => _push(context, const ManageAdminsScreen())));
      }
      items.add(_DrawerItem(label: 'Settings', icon: Icons.settings_rounded, color: const Color(0xFF475569), onTap: () => _push(context, const SettingsScreen())));
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
    final nav = context.watch<NavProvider>();
    final items = _buildItems(context, user, nav);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card — taps through to Settings, same destination as
            // the "Settings" item below. The chevron here was already
            // implying this was tappable; it just had nothing wired to it.
            InkWell(
              onTap: () => _push(context, const SettingsScreen()),
              child: Padding(
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
                    Icon(Icons.chevron_right, color: AppColors.textFaint),
                  ],
                ),
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
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.danger ? AppColors.dangerBg : item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, size: 20, color: item.danger ? AppColors.danger : item.color),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.danger ? AppColors.danger : AppColors.textPrimary,
                      ),
                    ),
                    trailing: (item.badgeCount ?? 0) > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              item.badgeCount! > 99 ? '99+' : item.badgeCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          )
                        : null,
                    onTap: item.onTap,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}