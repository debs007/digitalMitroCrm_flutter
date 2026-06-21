import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/employee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/state_views.dart';
import 'employee_detail_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _isLoading = true;
  String? _error;
  List<EmployeeModel> _employees = [];
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
      final employees = await EmployeeService.instance.getAll();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load employees.';
        _isLoading = false;
      });
    }
  }

  List<EmployeeModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees.where((e) => e.name.toLowerCase().contains(q) || e.email.toLowerCase().contains(q)).toList();
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _CreateEmployeeScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _confirmDelete(EmployeeModel e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('${e.name} will be marked as removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EmployeeService.instance.delete(e.id);
      _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err is ApiException ? err.message : 'Could not delete employee.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final canCreate = user?.isSuperAdmin == true || user?.can('employee', 'create') == true;
    final canDelete = user?.isSuperAdmin == true || user?.can('employee', 'delete') == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: _openCreateForm,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Search employees...', prefixIcon: Icon(Icons.search, size: 20)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? const EmptyView(message: 'No employees found.', icon: Icons.people_outline)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final e = _filtered[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: e)),
                                  ),
                                  child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: Row(
                                    children: [
                                      AppAvatar(name: e.name, imageUrl: e.avatar, size: 44),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.name, style: AppText.bodyLarge),
                                            Text(e.email, style: AppText.caption),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                _miniChip('${e.shiftType} shift'),
                                                _miniChip('${e.callbackCount} CB · ${e.saleCount} sale · ${e.transferCount} TF'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: AppColors.textFaint),
                                      if (canDelete)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                          onPressed: () => _confirmDelete(e),
                                        ),
                                    ],
                                  ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      );
}

class _CreateEmployeeScreen extends StatefulWidget {
  const _CreateEmployeeScreen();

  @override
  State<_CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<_CreateEmployeeScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _shift = 'Day';
  String _employeeType = 'Full-Time';
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
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _phone.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await EmployeeService.instance.create(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        shiftType: _shift,
        employeeType: _employeeType,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not create employee.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Employee')),
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
            const SizedBox(height: 14),
            const Text('Shift', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Day', 'Night'].map((s) => ChoiceChip(
                label: Text(s),
                selected: _shift == s,
                onSelected: (_) => setState(() => _shift = s),
              )).toList(),
            ),
            const SizedBox(height: 14),
            const Text('Employment type', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Full-Time', 'Part-Time'].map((t) => ChoiceChip(
                label: Text(t),
                selected: _employeeType == t,
                onSelected: (_) => setState(() => _employeeType = t),
              )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Create Employee'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
