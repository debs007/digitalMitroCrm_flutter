import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/admin_model.dart';
import '../../services/super_admin_service.dart';
import '../../widgets/state_views.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  bool _isLoading = true;
  String? _error;
  List<AdminModel> _admins = [];

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
    try {
      final admins = await SuperAdminService.instance.listAdmins();
      setState(() {
        _admins = admins;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load admins.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _CreateAdminScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _confirmDelete(AdminModel admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete admin?'),
        content: Text('${admin.name} will lose access immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SuperAdminService.instance.deleteAdmin(admin.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not delete admin.')),
        );
      }
    }
  }

  Future<void> _openEditor(AdminModel admin) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _AdminEditorScreen(admin: admin)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Admins')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateForm,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _admins.isEmpty
                  ? const EmptyView(message: 'No admins yet.', icon: Icons.shield_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _admins.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final admin = _admins[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    admin.name.isNotEmpty ? admin.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(admin.name, style: AppText.bodyLarge),
                                      Text(admin.email, style: AppText.caption),
                                      Text(DateFormat('d MMM yyyy').format(admin.createdAt), style: AppText.caption),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.tune, color: AppColors.primary),
                                  onPressed: () => _openEditor(admin),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _confirmDelete(admin),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _CreateAdminScreen extends StatefulWidget {
  const _CreateAdminScreen();

  @override
  State<_CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<_CreateAdminScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if ([_name, _email, _phone, _password].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SuperAdminService.instance.createAdmin(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not create admin.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Admin')),
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
            const Text('Name', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _name),
            const SizedBox(height: 14),
            const Text('Email', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            const Text('Phone', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            const Text('Temporary password', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _password, obscureText: true),
            const SizedBox(height: 8),
            const Text('New admin starts with every permission off — grant access after creating.', style: AppText.caption),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Create Admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-tab editor: Sidebar Access, Action Permissions, Scope.
/// Mirrors the web ManageAdmins.jsx panel exactly.
class _AdminEditorScreen extends StatefulWidget {
  final AdminModel admin;
  const _AdminEditorScreen({required this.admin});

  @override
  State<_AdminEditorScreen> createState() => _AdminEditorScreenState();
}

class _AdminEditorScreenState extends State<_AdminEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AdminPermissions _permissions;
  late bool _allEmployees;
  late List<String> _allowedEmployeeIds;
  late bool _allChannels;
  late List<String> _allowedChannelIds;

  List<PickerEmployee> _allEmployeesList = [];
  List<PickerChannel> _allChannelsList = [];
  bool _loadingPickers = true;
  bool _saving = false;

  static const Map<String, String> _sidebarLabels = {
    'notes': 'Notes', 'callbacks': 'Callbacks', 'attendance': 'Attendance',
    'transfer': 'Transfer', 'sales': 'Sales', 'activity': 'Activity',
    'concern': 'Concerns', 'notification': 'Notifications', 'tasks': 'Tasks', 'salary': 'Salary',
  };

  static const Map<String, String> _actionGroupLabels = {
    'task': 'Tasks', 'channel': 'Channels', 'salarySheet': 'Salary Sheet',
    'payslip': 'Payslips', 'report': 'Reports', 'taskManagement': 'Task Mgmt', 'employee': 'Employee Mgmt',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _permissions = widget.admin.permissions;
    _allEmployees = widget.admin.allEmployees;
    _allowedEmployeeIds = List.from(widget.admin.allowedEmployeeIds);
    _allChannels = widget.admin.allChannels;
    _allowedChannelIds = List.from(widget.admin.allowedChannelIds);
    _loadPickers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPickers() async {
    try {
      final employees = await SuperAdminService.instance.getAllEmployeesForPicker();
      final channels = await SuperAdminService.instance.getAllChannelsForPicker();
      setState(() {
        _allEmployeesList = employees;
        _allChannelsList = channels;
        _loadingPickers = false;
      });
    } catch (_) {
      setState(() => _loadingPickers = false);
    }
  }

  void _grantAll() => setState(() => _permissions = AdminPermissions.allGranted());
  void _revokeAll() => setState(() => _permissions = AdminPermissions.empty());

  Future<void> _savePermissions() async {
    setState(() => _saving = true);
    try {
      await SuperAdminService.instance.updatePermissions(widget.admin.id, _permissions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not save.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveScope() async {
    setState(() => _saving = true);
    try {
      await SuperAdminService.instance.updateScope(
        adminId: widget.admin.id,
        allEmployees: _allEmployees,
        allowedEmployeeIds: _allowedEmployeeIds,
        allChannels: _allChannels,
        allowedChannelIds: _allowedChannelIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scope saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not save.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.admin.name),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textFaint,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Sidebar Access'),
            Tab(text: 'Action Permissions'),
            Tab(text: 'Scope'),
          ],
        ),
        actions: [
          if (_tabController.index < 2)
            TextButton(
              onPressed: _saving ? null : _savePermissions,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSidebarTab(),
          _buildActionsTab(),
          _buildScopeTab(),
        ],
      ),
    );
  }

  Widget _buildSidebarTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _grantAll, child: const Text('Grant all')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _revokeAll,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Revoke all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._sidebarLabels.entries.map((entry) => SwitchListTile(
              title: Text(entry.value),
              value: _permissions.get(entry.key, 'access'),
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _permissions = _permissions.copyWith(entry.key, 'access', v)),
            )),
      ],
    );
  }

  Widget _buildActionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: AdminPermissions.actionGroups.entries.map((group) {
        final groupKey = group.key;
        final actions = group.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.neutralBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_actionGroupLabels[groupKey] ?? groupKey, style: AppText.captionBold),
              const SizedBox(height: 6),
              ...actions.map((action) {
                final label = action.substring(0, 1).toUpperCase() + action.substring(1);
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(label),
                  value: _permissions.get(groupKey, action),
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _permissions = _permissions.copyWith(groupKey, action, v)),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScopeTab() {
    if (_loadingPickers) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('Employee Access', style: AppText.h3)),
            Switch(
              value: _allEmployees,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _allEmployees = v),
            ),
          ],
        ),
        Text(_allEmployees ? 'Full access to all employees' : '${_allowedEmployeeIds.length} selected', style: AppText.caption),
        if (!_allEmployees) ...[
          const SizedBox(height: 10),
          ..._allEmployeesList.map((emp) => CheckboxListTile(
                title: Text(emp.name),
                value: _allowedEmployeeIds.contains(emp.id),
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _allowedEmployeeIds.add(emp.id);
                  } else {
                    _allowedEmployeeIds.remove(emp.id);
                  }
                }),
              )),
        ],
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text('Channel Access', style: AppText.h3)),
            Switch(
              value: _allChannels,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _allChannels = v),
            ),
          ],
        ),
        Text(_allChannels ? 'Full access to all channels' : '${_allowedChannelIds.length} selected', style: AppText.caption),
        if (!_allChannels) ...[
          const SizedBox(height: 10),
          ..._allChannelsList.map((ch) => CheckboxListTile(
                title: Text('#${ch.name}'),
                value: _allowedChannelIds.contains(ch.id),
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _allowedChannelIds.add(ch.id);
                  } else {
                    _allowedChannelIds.remove(ch.id);
                  }
                }),
              )),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveScope,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save scope'),
          ),
        ),
      ],
    );
  }
}
