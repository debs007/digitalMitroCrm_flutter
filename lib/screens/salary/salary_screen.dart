import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      color: AppColors.primary,
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
                Text(sheet.title.isNotEmpty ? sheet.title : sheet.monthLabel, style: AppText.bodyLarge),
                Text(sheet.monthLabel, style: AppText.caption),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
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
      color: AppColors.primary,
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
                  child: const Icon(Icons.description_outlined, color: AppColors.primary),
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
                      : const Icon(Icons.download_outlined, color: AppColors.primary),
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
