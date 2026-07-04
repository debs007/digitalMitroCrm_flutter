import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/payslip_salary_model.dart';
import '../../models/employee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';
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
  void Function(dynamic)? _onSoftRefresh;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _isAdmin = user?.isAdmin ?? false;
    _canUpload = user?.isSuperAdmin == true || user?.can('salarySheet', 'upload') == true;
    _canRevoke = user?.isSuperAdmin == true || user?.can('salarySheet', 'revoke') == true;
    _tabController = TabController(length: _isAdmin ? 1 : 2, vsync: this);
    _load();
    final socket = SocketService.instance;
    _onSoftRefresh = (data) {
      if (data is Map && data['type']?.toString() == 'Salary') _load();
    };
    socket.on('soft-refresh', _onSoftRefresh!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_onSoftRefresh != null) SocketService.instance.off('soft-refresh', _onSoftRefresh);
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

  Future<void> _openUploadMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.table_chart_outlined, color: AppColors.primary)),
              title: const Text('Upload Salary Sheet', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('CSV with all employees for a month'),
              onTap: () => Navigator.pop(ctx, 'sheet'),
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.picture_as_pdf_outlined, color: AppColors.info)),
              title: const Text('Bulk Upload Payslips', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Individual PDF per employee for a month'),
              onTap: () => Navigator.pop(ctx, 'payslips'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'sheet') {
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
    } else if (choice == 'payslips') {
      final uploaded = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => const _BulkUploadPayslipsSheet(),
      );
      if (uploaded == true) _load();
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
              onPressed: _openUploadMenu,
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

/// Bulk payslip upload — pick multiple PDFs, assign each to an employee,
/// then upload all in one shot for the selected month/year.
class _BulkUploadPayslipsSheet extends StatefulWidget {
  const _BulkUploadPayslipsSheet();

  @override
  State<_BulkUploadPayslipsSheet> createState() => _BulkUploadPayslipsSheetState();
}

class _BulkUploadPayslipsSheetState extends State<_BulkUploadPayslipsSheet> {
  List<EmployeeModel> _employees = [];
  bool _loadingEmployees = true;
  // file → assigned employee id
  final Map<File, String> _assignments = {};
  // file → display name
  final Map<File, String> _fileNames = {};
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  bool _uploading = false;
  String? _resultMsg;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final list = await EmployeeService.instance.getAll();
      setState(() {
        _employees = list;
        _loadingEmployees = false;
      });
    } catch (_) {
      setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path == null) continue;
        final file = File(f.path!);
        if (!_fileNames.containsKey(file)) {
          _fileNames[file] = f.name;
          _assignments[file] = '';
        }
      }
    });
  }

  void _removeFile(File f) => setState(() { _assignments.remove(f); _fileNames.remove(f); });

  Future<void> _upload() async {
    final unassigned = _assignments.entries.where((e) => e.value.isEmpty).length;
    if (_assignments.isEmpty) {
      setState(() => _resultMsg = 'Pick at least one PDF first.');
      return;
    }
    if (unassigned > 0) {
      setState(() => _resultMsg = 'Assign an employee to every file first ($unassigned unassigned).');
      return;
    }
    setState(() { _uploading = true; _resultMsg = null; });
    try {
      final result = await PayslipSalaryService.instance.bulkUploadPayslips(
        year: _year,
        month: _month,
        files: Map.from(_assignments),
      );
      final uploaded = result['uploaded'] ?? 0;
      final failed = result['failed'] ?? 0;
      if (!mounted) return;
      if (failed == 0) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _resultMsg = '$uploaded uploaded, $failed failed.';
          _uploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _resultMsg = e is ApiException ? e.message : 'Upload failed.';
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text('Bulk Upload Payslips', style: AppText.h3),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _month,
                      decoration: const InputDecoration(labelText: 'Month', isDense: true),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][i]))),
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _year,
                      decoration: const InputDecoration(labelText: 'Year', isDense: true),
                      items: List.generate(5, (i) => DateTime.now().year - i).map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Pick PDFs'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ),
            if (_resultMsg != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(_resultMsg!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            const Divider(height: 20),
            Expanded(
              child: _loadingEmployees
                  ? Center(child: CircularProgressIndicator(color: AppColors.loader))
                  : _assignments.isEmpty
                      ? Center(child: Text('No PDFs selected yet.', style: AppText.bodyMuted))
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _assignments.entries.map((entry) {
                            final file = entry.key;
                            final assigned = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.picture_as_pdf, color: AppColors.danger, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_fileNames[file] ?? file.path.split('/').last, style: AppText.body, overflow: TextOverflow.ellipsis)),
                                        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeFile(file), padding: EdgeInsets.zero),
                                      ],
                                    ),
                                    DropdownButtonFormField<String>(
                                      value: assigned.isEmpty ? null : assigned,
                                      hint: const Text('Assign to employee'),
                                      decoration: const InputDecoration(isDense: true),
                                      items: _employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (v) => setState(() => _assignments[file] = v ?? ''),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _upload,
                  child: _uploading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text('Upload ${_assignments.length} Payslip${_assignments.length == 1 ? '' : 's'}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
