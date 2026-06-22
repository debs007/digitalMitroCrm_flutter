import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/employee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';
import '../../services/notes_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/state_views.dart';

/// The backend stores notes as one array-of-strings per user (upserted
/// wholesale). We present this as a single multi-line editor, splitting
/// on newlines for save and joining with newlines for display.
///
/// Admin/SuperAdmin get an employee picker first (matching the web app's
/// AdminNotes.jsx) — selecting someone shows their notes read-only, since
/// there's no backend endpoint to edit another person's notes.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isAdmin = false;
  EmployeeModel? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return const _OwnNotesView();
    if (_selectedEmployee == null) {
      return _EmployeePicker(onSelected: (e) => setState(() => _selectedEmployee = e));
    }
    return _EmployeeNotesView(
      employee: _selectedEmployee!,
      onBack: () => setState(() => _selectedEmployee = null),
    );
  }
}

// ── Employee's own editable notes ─────────────────────────────────────────

class _OwnNotesView extends StatefulWidget {
  const _OwnNotesView();

  @override
  State<_OwnNotesView> createState() => _OwnNotesViewState();
}

class _OwnNotesViewState extends State<_OwnNotesView> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _saving = false;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notes = await NotesService.instance.getNotes();
      _controller.text = notes.join('\n');
      setState(() {
        _isLoading = false;
        _dirty = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load notes.';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final lines = _controller.text.split('\n');
      await NotesService.instance.saveNotes(lines);
      setState(() {
        _saving = false;
        _dirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved.')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not save notes.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          TextButton(
            onPressed: (_dirty && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
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
                    child: Container(
                      height: MediaQuery.of(context).size.height - 200,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Jot down anything you want to remember...',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ── Admin: pick an employee ────────────────────────────────────────────────

class _EmployeePicker extends StatefulWidget {
  final void Function(EmployeeModel) onSelected;
  const _EmployeePicker({required this.onSelected});

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
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
    return _employees.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Search employee to view notes...', prefixIcon: Icon(Icons.search, size: 20)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final e = _filtered[index];
                            return ListTile(
                              tileColor: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.divider),
                              ),
                              leading: AppAvatar(name: e.name, imageUrl: e.avatar, size: 40),
                              title: Text(e.name),
                              subtitle: Text(e.email, style: AppText.caption),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => widget.onSelected(e),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Admin: read-only view of one employee's notes ──────────────────────────

class _EmployeeNotesView extends StatefulWidget {
  final EmployeeModel employee;
  final VoidCallback onBack;
  const _EmployeeNotesView({required this.employee, required this.onBack});

  @override
  State<_EmployeeNotesView> createState() => _EmployeeNotesViewState();
}

class _EmployeeNotesViewState extends State<_EmployeeNotesView> {
  bool _isLoading = true;
  String? _error;
  String _notesText = '';

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
      final notes = await NotesService.instance.getNotesForEmployee(widget.employee.id);
      setState(() {
        _notesText = notes.join('\n');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load notes.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: Text("${widget.employee.name}'s Notes"),
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
                    child: _notesText.trim().isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: EmptyView(message: 'This employee has no notes yet.', icon: Icons.notes_outlined),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(_notesText, style: AppText.body),
                          ),
                  ),
                ),
    );
  }
}
