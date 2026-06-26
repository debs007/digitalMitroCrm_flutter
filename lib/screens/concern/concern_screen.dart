import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/concern_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/concern_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

class ConcernScreen extends StatefulWidget {
  const ConcernScreen({super.key});

  @override
  State<ConcernScreen> createState() => _ConcernScreenState();
}

class _ConcernScreenState extends State<ConcernScreen> {
  bool _isLoading = true;
  String? _error;
  List<ConcernModel> _concerns = [];
  bool _isAdmin = false;
  String? _busyId;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final concerns = _isAdmin ? await ConcernService.instance.getAll() : await ConcernService.instance.getMine();
      setState(() {
        _concerns = concerns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // 404 from getMine means "no concerns yet" on this backend, not a real error.
        if (e is ApiException && e.statusCode == 404) {
          _concerns = [];
        } else {
          _error = e is ApiException ? e.message : 'Could not load concerns.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _approve(ConcernModel c) async {
    setState(() => _busyId = c.id);
    try {
      await ConcernService.instance.approve(userId: c.userId, concernId: c.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not approve.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(ConcernModel c) async {
    setState(() => _busyId = c.id);
    try {
      await ConcernService.instance.reject(userId: c.userId, concernId: c.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not reject.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openSubmitForm() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _SubmitConcernSheet(),
      ),
    );
    if (submitted == true) _load();
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value, style: AppText.body)),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return AppColors.success;
      case 'Rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isAdmin ? 'Concerns' : 'My Concerns')),
      floatingActionButton: _isAdmin
          ? null
          : FloatingActionButton(
              onPressed: _openSubmitForm,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _concerns.isEmpty
                  ? const EmptyView(message: 'No concerns to show.', icon: Icons.report_gmailerrorred_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.loader,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _concerns.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final c = _concerns[index];
                          final busy = _busyId == c.id;
                          final isExpanded = _expandedId == c.id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _expandedId = isExpanded ? null : c.id),
                            child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isExpanded ? AppColors.primary : AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Always show who this concern belongs to when we have
                                    // a name (i.e. the admin/superadmin view) — this was
                                    // previously buried inline with the concern type.
                                    if (_isAdmin && c.userName.isNotEmpty) ...[
                                      AppAvatar(name: c.userName, imageUrl: c.userAvatar, size: 34),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_isAdmin && c.userName.isNotEmpty)
                                            Text(c.userName, style: AppText.bodyLarge),
                                          Text(
                                            c.concernType,
                                            style: (_isAdmin && c.userName.isNotEmpty) ? AppText.caption : AppText.bodyLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusChip(
                                      label: c.status,
                                      color: _statusColor(c.status),
                                      background: _statusColor(c.status).withValues(alpha: 0.12),
                                    ),
                                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textFaint),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  c.message,
                                  style: AppText.body,
                                  maxLines: isExpanded ? null : 2,
                                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                                ),
                                if (isExpanded) ...[
                                  const Divider(height: 18),
                                  if (c.concernDate != null) _detailRow('For date', c.concernDate!),
                                  if (c.actualPunchIn != null) _detailRow('Actual punch in', c.actualPunchIn!),
                                  if (c.actualPunchOut != null) _detailRow('Actual punch out', c.actualPunchOut!),
                                  _detailRow('Submitted', DateFormat('d MMM yyyy, hh:mm a').format(c.createdAt)),
                                ] else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(DateFormat('d MMM yyyy, hh:mm a').format(c.createdAt), style: AppText.caption),
                                  ),
                                if (_isAdmin && c.status == 'Pending') ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: busy ? null : () => _reject(c),
                                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: busy ? null : () => _approve(c),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                          child: busy
                                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : const Text('Approve'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _SubmitConcernSheet extends StatefulWidget {
  const _SubmitConcernSheet();

  @override
  State<_SubmitConcernSheet> createState() => _SubmitConcernSheetState();
}

class _SubmitConcernSheetState extends State<_SubmitConcernSheet> {
  String _type = 'Leave';
  final _message = TextEditingController();
  DateTime? _concernDate;
  bool _submitting = false;
  String? _error;

  static const _types = ['Leave', 'Punch In Correction', 'Punch Out Correction', 'Other'];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _concernDate = picked);
  }

  Future<void> _submit() async {
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Please describe your concern.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ConcernService.instance.submit(
        concernType: _type,
        message: _message.text.trim(),
        concernDate: _concernDate != null ? DateFormat('yyyy-MM-dd').format(_concernDate!) : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not submit.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Raise a Concern', style: AppText.h3),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: TextStyle(color: AppColors.danger)),
            ),
          Text('Type', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _types.map((t) => ChoiceChip(
              label: Text(t),
              selected: _type == t,
              onSelected: (_) => setState(() => _type = t),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Text('For date (optional)', style: AppText.label),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                _concernDate == null ? 'Select date' : DateFormat('d MMM yyyy').format(_concernDate!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Message', style: AppText.label),
          const SizedBox(height: 8),
          TextField(controller: _message, maxLines: 4, decoration: const InputDecoration(hintText: 'Describe your concern...')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
