import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/payslip_salary_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/payslip_salary_service.dart';
import '../../widgets/state_views.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<PayslipModel> _payslips = [];
  List<SalarySheetModel> _sheets = [];
  String? _downloadingId;
  String? _deletingId;
  bool _isAdmin = false;
  bool _canUpload = false;
  bool _canRevoke = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _isAdmin = user?.isAdmin ?? false;
    _canUpload = user?.isSuperAdmin == true || user?.can('salarySheet', 'upload') == true;
    _canRevoke = user?.isSuperAdmin == true || user?.can('salarySheet', 'revoke') == true;
    _tabController = TabController(length: _isAdmin ? 1 : 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sheets = await PayslipSalaryService.instance.getSalarySheets();
      List<PayslipModel> payslips = [];
      if (!_isAdmin) {
        payslips = await PayslipSalaryService.instance.getMyPayslips();
      }
      setState(() {
        _sheets = sheets;
        _payslips = payslips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load salary data.';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPayslip(PayslipModel p) async {
    setState(() => _downloadingId = p.id);
    try {
      final file = await PayslipSalaryService.instance.downloadPayslip(p.id, p.fileName);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not download payslip.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _deleteSheet(SalarySheetModel sheet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this salary sheet?'),
        content: Text(sheet.monthLabel),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingId = sheet.id);
    try {
      await PayslipSalaryService.instance.deleteSalarySheet(sheet.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not delete sheet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _openUploadSheet() async {
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _UploadSalarySheet(),
      ),
    );
    if (uploaded == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canUpload
          ? FloatingActionButton(
              onPressed: _openUploadSheet,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.upload_file, color: Colors.white),
            )
          : null,
      appBar: AppBar(
        title: const Text('Salary'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textFaint,
          indicatorColor: AppColors.primary,
          tabs: [
            const Tab(text: 'Salary Sheets'),
            if (!_isAdmin) const Tab(text: 'Payslips'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSalarySheets(),
                    if (!_isAdmin) _buildPayslips(),
                  ],
                ),
    );
  }

  Widget _buildSalarySheets() {
    if (_sheets.isEmpty) {
      return const EmptyView(message: 'No salary sheets uploaded yet.', icon: Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.loader,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sheets.length,
        itemBuilder: (context, index) {
          final sheet = _sheets[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sheet.title.isNotEmpty ? sheet.title : sheet.monthLabel, style: AppText.bodyLarge),
                          Text(sheet.monthLabel, style: AppText.caption),
                        ],
                      ),
                    ),
                    if (_canRevoke)
                      _deletingId == sheet.id
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                              onPressed: () => _deleteSheet(sheet),
                            ),
                  ],
                ),
                const Divider(height: 16),
                ...sheet.rows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.name.isNotEmpty ? row.name : row.email, style: AppText.body),
                                if (_isAdmin) Text(row.position, style: AppText.caption),
                              ],
                            ),
                          ),
                          Text(
                            row.inHandSalary.isNotEmpty ? '₹${row.inHandSalary}' : '—',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPayslips() {
    if (_payslips.isEmpty) {
      return const EmptyView(message: 'No payslips uploaded yet.', icon: Icons.description_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.loader,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _payslips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final p = _payslips[index];
          final isDownloading = _downloadingId == p.id;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.description_outlined, color: AppColors.loader),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.monthLabel, style: AppText.bodyLarge),
                      if (p.note.isNotEmpty) Text(p.note, style: AppText.caption),
                    ],
                  ),
                ),
                IconButton(
                  icon: isDownloading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined, color: AppColors.loader),
                  onPressed: isDownloading ? null : () => _downloadPayslip(p),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UploadSalarySheet extends StatefulWidget {
  const _UploadSalarySheet();

  @override
  State<_UploadSalarySheet> createState() => _UploadSalarySheetState();
}

class _UploadSalarySheetState extends State<_UploadSalarySheet> {
  File? _csvFile;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final _titleController = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _csvFile = File(result.files.single.path!));
    }
  }

  Future<void> _submit() async {
    if (_csvFile == null) {
      setState(() => _error = 'Please select a CSV file.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await PayslipSalaryService.instance.uploadSalarySheetCsv(
        csvFile: _csvFile!,
        month: _month,
        year: _year,
        title: _titleController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Upload failed. Check the CSV headers match the template.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(6, (i) => DateTime.now().year - 3 + i);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Upload Salary Sheet', style: AppText.h3),
          const SizedBox(height: 4),
          Text(
            'CSV columns: EmpId, Email, Name, Position, Gross Salary, Attendance, Total Absent, In Hand Salary, Ptax, Remarks',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.danger)),
            ),

          Text('Month', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (i) {
              final m = i + 1;
              final selected = _month == m;
              return ChoiceChip(
                label: Text(_monthNames[i].substring(0, 3)),
                selected: selected,
                onSelected: (_) => setState(() => _month = m),
              );
            }),
          ),
          const SizedBox(height: 16),

          Text('Year', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: years.map((y) => ChoiceChip(
              label: Text(y.toString()),
              selected: _year == y,
              onSelected: (_) => setState(() => _year = y),
            )).toList(),
          ),
          const SizedBox(height: 16),

          Text('Title (optional)', style: AppText.label),
          const SizedBox(height: 8),
          TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'e.g. June 2026 Payroll')),
          const SizedBox(height: 16),

          Text('CSV file', style: AppText.label),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickCsv,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.attach_file, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _csvFile?.path.split('/').last ?? 'Select a .csv file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Upload'),
            ),
          ),
        ],
      ),
    );
  }
}