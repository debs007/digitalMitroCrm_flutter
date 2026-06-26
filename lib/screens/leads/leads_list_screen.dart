import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/lead_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/lead_service.dart';
import '../../widgets/state_views.dart';

/// One screen handles Callback, Sale, and Transfer — they're functionally
/// identical lead-tracking forms on the backend, just mounted under
/// different paths. [type] selects which.
class LeadsListScreen extends StatefulWidget {
  final LeadType type;

  const LeadsListScreen({super.key, required this.type});

  @override
  State<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends State<LeadsListScreen> {
  bool _isLoading = true;
  String? _error;
  List<LeadModel> _items = [];
  int _page = 1;
  int _totalPages = 1;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
      final result = isAdmin
          ? await LeadService.instance.getAll(widget.type, page: page)
          : await LeadService.instance.getMine(widget.type, page: page);
      setState(() {
        _items = result.items;
        _page = page;
        _totalPages = result.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load ${widget.type.label.toLowerCase()}s.';
        _isLoading = false;
      });
    }
  }

  Future<void> _delete(LeadModel lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this ${widget.type.label.toLowerCase()}?'),
        content: Text(lead.name.isNotEmpty ? lead.name : lead.phone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await LeadService.instance.delete(widget.type, lead.id);
      _load(page: _page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not delete.')),
        );
      }
    }
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _LeadFormScreen(type: widget.type)),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type.label}s'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              (context.watch<AuthProvider>().user?.isAdmin ?? false) ? 'All employees' : 'Mine',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateForm,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: () => _load(page: _page))
              : _items.isEmpty
                  ? EmptyView(message: 'No ${widget.type.label.toLowerCase()}s yet.', icon: Icons.inbox_outlined)
                  : RefreshIndicator(
                      onRefresh: () => _load(page: _page),
                      color: AppColors.loader,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length + (_totalPages > 1 ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return _buildPager();
                          }
                          final lead = _items[index];
                          final isExpanded = _expandedId == lead.id;
                          return Dismissible(
                            key: ValueKey(lead.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(14)),
                              child: Icon(Icons.delete_outline, color: AppColors.danger),
                            ),
                            confirmDismiss: (_) async {
                              await _delete(lead);
                              return false; // we handle removal via reload
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => _expandedId = isExpanded ? null : lead.id),
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
                                        Expanded(
                                          child: Text(
                                            lead.name.isNotEmpty ? lead.name : 'No name',
                                            style: AppText.bodyLarge,
                                          ),
                                        ),
                                        if (lead.budget.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Text(lead.budget, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                                          ),
                                        Icon(
                                          isExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: AppColors.textFaint,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(lead.phone, style: AppText.bodyMuted),
                                    if (!isExpanded && lead.email.isNotEmpty) Text(lead.email, style: AppText.caption),
                                    if (isExpanded) ...[
                                      const Divider(height: 20),
                                      _detailRow('Email', lead.email),
                                      _detailRow('Domain', lead.domainName),
                                      _detailRow('Address', lead.address),
                                      _detailRow('Country', lead.country),
                                      _detailRow('Call date', lead.callDate),
                                      _detailRow('Budget', lead.budget),
                                      const SizedBox(height: 4),
                                      Text('Comments', style: AppText.label),
                                      const SizedBox(height: 4),
                                      Text(
                                        lead.comments.isNotEmpty ? lead.comments : 'No comments.',
                                        style: AppText.body,
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => _delete(lead),
                                          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                          label: Text('Delete', style: TextStyle(color: AppColors.danger)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value, style: AppText.body)),
        ],
      ),
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
          ),
          Text('Page $_page of $_totalPages', style: AppText.caption),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _totalPages ? () => _load(page: _page + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _LeadFormScreen extends StatefulWidget {
  final LeadType type;
  const _LeadFormScreen({required this.type});

  @override
  State<_LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<_LeadFormScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _domain = TextEditingController();
  final _address = TextEditingController();
  final _country = TextEditingController();
  final _budget = TextEditingController();
  final _comments = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _domain, _address, _country, _budget, _comments]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Phone number is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final lead = LeadModel(
        id: '',
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        domainName: _domain.text.trim(),
        address: _address.text.trim(),
        country: _country.text.trim(),
        zipcode: '',
        comments: _comments.text.trim(),
        budget: _budget.text.trim(),
        callDate: DateTime.now().toIso8601String().split('T').first,
        createdAt: DateTime.now(),
      );
      await LeadService.instance.create(widget.type, lead);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not save.';
        _submitting = false;
      });
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 6),
          TextField(controller: controller, keyboardType: keyboardType),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New ${widget.type.label}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              ),
            _field('Name', _name),
            _field('Phone *', _phone, keyboardType: TextInputType.phone),
            _field('Email', _email, keyboardType: TextInputType.emailAddress),
            _field('Domain name', _domain),
            _field('Address', _address),
            _field('Country', _country),
            _field('Budget', _budget),
            _field('Comments', _comments),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Save ${widget.type.label}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
