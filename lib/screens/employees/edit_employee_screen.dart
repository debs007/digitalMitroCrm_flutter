import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/employee_model.dart';
import '../../services/employee_service.dart';
import '../../widgets/state_views.dart';

/// Edit an existing employee's details — mirrors the web app's
/// "Update Employee" page (name, employment type, email, job description,
/// shift, phone) and calls the same PUT /auth/:id endpoint via
/// EmployeeService.update(). Pop with `true` on success so the caller
/// knows to refresh.
class EditEmployeeScreen extends StatefulWidget {
  final EmployeeModel employee;
  const EditEmployeeScreen({super.key, required this.employee});

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _jobDescription;
  late String _shift;
  late String _employeeType;

  bool _isLoading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.employee.name);
    _email = TextEditingController(text: widget.employee.email);
    _phone = TextEditingController(text: widget.employee.phone);
    _jobDescription = TextEditingController(text: widget.employee.jobDescription);
    _shift = widget.employee.shiftType.isNotEmpty ? widget.employee.shiftType : 'Day';
    _employeeType = widget.employee.employeeType.isNotEmpty ? widget.employee.employeeType : 'Full-Time';
    _loadFresh();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _jobDescription]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The employee list only carries a summary — jobDescription in
  /// particular isn't in it — so pull the full record before editing,
  /// same as the web app's edit page does. Pre-filled fields above already
  /// give the user something to look at immediately; this just tops them
  /// up once the fresher copy arrives. A failed refresh isn't fatal: the
  /// form stays usable with whatever was passed in.
  Future<void> _loadFresh() async {
    try {
      final fresh = await EmployeeService.instance.getById(widget.employee.id);
      if (!mounted) return;
      setState(() {
        _name.text = fresh.name;
        _email.text = fresh.email;
        _phone.text = fresh.phone;
        _jobDescription.text = fresh.jobDescription;
        if (fresh.shiftType.isNotEmpty) _shift = fresh.shiftType;
        if (fresh.employeeType.isNotEmpty) _employeeType = fresh.employeeType;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Name, email, and phone are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await EmployeeService.instance.update(
        id: widget.employee.id,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        shiftType: _shift,
        employeeType: _employeeType,
        jobDescription: _jobDescription.text,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not update employee.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Employee')),
      body: _isLoading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: TextStyle(color: AppColors.danger)),
                    ),
                  Text('Name', style: AppText.label),
                  const SizedBox(height: 6),
                  TextField(controller: _name),
                  const SizedBox(height: 14),
                  Text('Email', style: AppText.label),
                  const SizedBox(height: 6),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  Text('Phone', style: AppText.label),
                  const SizedBox(height: 6),
                  TextField(controller: _phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  Text('Job description', style: AppText.label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _jobDescription,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'What does this employee do? Role, responsibilities, etc.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Shift', style: AppText.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Day', 'Night']
                        .map((s) => ChoiceChip(
                              label: Text(s),
                              selected: _shift == s,
                              onSelected: (_) => setState(() => _shift = s),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Employment type', style: AppText.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Full-Time', 'Part-Time']
                        .map((t) => ChoiceChip(
                              label: Text(t),
                              selected: _employeeType == t,
                              onSelected: (_) => setState(() => _employeeType = t),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
