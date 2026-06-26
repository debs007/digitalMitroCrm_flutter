import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/employee_model.dart';
import '../../models/attendance_model.dart';
import '../../models/lead_model.dart';
import '../../models/payslip_salary_model.dart';
import '../../services/employee_service.dart';
import '../../services/attendance_service.dart';
import '../../services/lead_service.dart';
import '../../services/payslip_salary_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/state_views.dart';

/// Mirrors the web app's Activity → EmployeeDashboard flow: tap an
/// employee to see their attendance, leads, and payslips — not just the
/// directory row.
class EmployeeDetailScreen extends StatefulWidget {
  final EmployeeModel employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(name: widget.employee.name, imageUrl: widget.employee.avatar, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.employee.name, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textFaint,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
            Tab(text: 'Callbacks'),
            Tab(text: 'Sales'),
            Tab(text: 'Transfers'),
            Tab(text: 'Payslips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(employee: widget.employee),
          _EmployeeAttendanceTab(employeeId: widget.employee.id),
          _LeadsTab(type: LeadType.callback, employeeId: widget.employee.id),
          _LeadsTab(type: LeadType.sale, employeeId: widget.employee.id),
          _LeadsTab(type: LeadType.transfer, employeeId: widget.employee.id),
          _PayslipsTab(employee: widget.employee),
        ],
      ),
    );
  }
}

// ── Overview ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  final EmployeeModel employee;
  const _OverviewTab({required this.employee});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _isLoading = true;
  String? _error;
  Map<String, int> _summary = {};

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
      final summary = await EmployeeService.instance.getDashboardSummary(widget.employee.id);
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load summary.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final e = widget.employee;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.loader,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Email', e.email),
                _infoRow('Phone', e.phone),
                _infoRow('Shift', '${e.shiftType} shift'),
                _infoRow('Employment', e.employeeType),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _statTile('Attendance', _summary['attendance'] ?? 0, Icons.calendar_today_outlined, AppColors.info, AppColors.infoBg),
              _statTile('Callbacks', _summary['callback'] ?? 0, Icons.call_outlined, AppColors.warning, AppColors.warningBg),
              _statTile('Sales', _summary['sale'] ?? 0, Icons.show_chart_outlined, AppColors.success, AppColors.successBg),
              _statTile('Transfers', _summary['transfer'] ?? 0, Icons.swap_horiz_outlined, AppColors.loader, AppColors.primaryTint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value.isNotEmpty ? value : '—', style: AppText.body)),
        ],
      ),
    );
  }

  Widget _statTile(String label, int count, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const Spacer(),
          Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ── Attendance ───────────────────────────────────────────────────────────

class _EmployeeAttendanceTab extends StatefulWidget {
  final String employeeId;
  const _EmployeeAttendanceTab({required this.employeeId});

  @override
  State<_EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends State<_EmployeeAttendanceTab> {
  bool _isLoading = true;
  String? _error;
  List<AttendanceRecord> _records = [];
  DateTime _month = DateTime.now();

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
      final records = await AttendanceService.instance.getForEmployee(
        employeeId: widget.employeeId,
        month: _month.month,
        year: _month.year,
      );
      records.sort((a, b) => b.currentDate.compareTo(a.currentDate));
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load attendance.';
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
              Text(DateFormat('MMMM yyyy').format(_month), style: AppText.h3),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _records.isEmpty
                      ? const EmptyView(message: 'No attendance records this month.', icon: Icons.event_busy)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = _records[index];
                            final label = r.isInProgress ? 'Work in progress' : r.workStatus;
                            final color = r.isInProgress ? AppColors.warning : AppColors.attendanceColor(r.status);
                            final bg = r.isInProgress ? AppColors.warningBg : AppColors.attendanceBg(r.status);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(DateFormat('d MMMM').format(r.currentDate), style: AppText.bodyLarge),
                                        Text(DateFormat('EEEE').format(r.currentDate), style: AppText.caption),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                                    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ── Leads (Callbacks / Sales / Transfers) ─────────────────────────────────

class _LeadsTab extends StatefulWidget {
  final LeadType type;
  final String employeeId;
  const _LeadsTab({required this.type, required this.employeeId});

  @override
  State<_LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<_LeadsTab> {
  bool _isLoading = true;
  String? _error;
  List<LeadModel> _items = [];

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
      final items = await LeadService.instance.getForEmployee(widget.type, widget.employeeId);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load ${widget.type.label.toLowerCase()}s.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return EmptyView(message: 'No ${widget.type.label.toLowerCase()}s yet.', icon: Icons.inbox_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.loader,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final lead = _items[index];
          return Container(
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
                    Expanded(child: Text(lead.name.isNotEmpty ? lead.name : 'No name', style: AppText.bodyLarge)),
                    if (lead.budget.isNotEmpty)
                      Text(lead.budget, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(lead.phone, style: AppText.bodyMuted),
                if (lead.email.isNotEmpty) Text(lead.email, style: AppText.caption),
                if (lead.comments.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(lead.comments, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Payslips ────────────────────────────────────────────────────────────

class _PayslipsTab extends StatefulWidget {
  final EmployeeModel employee;
  const _PayslipsTab({required this.employee});

  @override
  State<_PayslipsTab> createState() => _PayslipsTabState();
}

class _PayslipsTabState extends State<_PayslipsTab> {
  bool _isLoading = true;
  String? _error;
  List<PayslipModel> _payslips = [];
  String? _busyId;

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
      final payslips = await PayslipSalaryService.instance.getPayslipsForEmployee(widget.employee.id);
      setState(() {
        _payslips = payslips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load payslips.';
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadPayslip() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);

    final monthYear = await _pickMonthYear();
    if (monthYear == null) return;

    setState(() => _busyId = 'uploading');
    try {
      await PayslipSalaryService.instance.uploadPayslipForEmployee(
        employeeId: widget.employee.id,
        pdfFile: file,
        year: monthYear.year,
        month: monthYear.month,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Upload failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<DateTime?> _pickMonthYear() async {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023, 1),
      lastDate: DateTime.now(),
      helpText: 'Select payslip month',
    );
  }

  Future<void> _openPayslip(PayslipModel p) async {
    setState(() => _busyId = p.id);
    try {
      final file = await PayslipSalaryService.instance.downloadPayslip(p.id, p.fileName);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not open payslip.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deletePayslip(PayslipModel p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payslip?'),
        content: Text(p.monthLabel),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PayslipSalaryService.instance.deletePayslip(p.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not delete.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _busyId == 'uploading' ? null : _uploadPayslip,
        backgroundColor: AppColors.primary,
        child: _busyId == 'uploading'
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.upload_file, color: Colors.white),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _payslips.isEmpty
                  ? const EmptyView(message: 'No payslips uploaded yet.', icon: Icons.description_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.loader,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _payslips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = _payslips[index];
                          final isBusy = _busyId == p.id;
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
                                Expanded(child: Text(p.monthLabel, style: AppText.bodyLarge)),
                                isBusy
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.loader),
                                            onPressed: () => _openPayslip(p),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                            onPressed: () => _deletePayslip(p),
                                          ),
                                        ],
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