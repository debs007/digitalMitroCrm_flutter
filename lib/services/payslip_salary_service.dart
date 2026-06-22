import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/payslip_salary_model.dart';

class PayslipSalaryService {
  PayslipSalaryService._();
  static final PayslipSalaryService instance = PayslipSalaryService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<PayslipModel>> getMyPayslips() async {
    final res = await _api.get(ApiConstants.myPayslips);
    final list = res['payslips'];
    if (list is List) {
      return list.map((p) => PayslipModel.fromJson(Map<String, dynamic>.from(p))).toList();
    }
    return [];
  }

  /// Admin/SuperAdmin viewing one employee's payslips — Activity → Employee
  /// Detail screen.
  Future<List<PayslipModel>> getPayslipsForEmployee(String employeeId) async {
    final res = await _api.get(ApiConstants.employeePayslips(employeeId));
    final list = res['payslips'];
    if (list is List) {
      return list.map((p) => PayslipModel.fromJson(Map<String, dynamic>.from(p))).toList();
    }
    return [];
  }

  /// Admin uploads a payslip PDF for a specific employee.
  Future<void> uploadPayslipForEmployee({
    required String employeeId,
    required File pdfFile,
    required int year,
    required int month,
    String note = '',
  }) async {
    final formData = FormData.fromMap({
      'employeeId': employeeId,
      'year': year,
      'month': month,
      'note': note,
      'file': await MultipartFile.fromFile(pdfFile.path, filename: pdfFile.path.split('/').last),
    });
    await ApiClient.instance.dio.post(ApiConstants.payslipsBase, data: formData);
  }

  Future<void> deletePayslip(String payslipId) async {
    await _api.delete(ApiConstants.payslipDelete(payslipId));
  }

  /// For employees: returns sheets containing only their own row.
  /// For admins: returns every uploaded sheet in full.
  Future<List<SalarySheetModel>> getSalarySheets() async {
    final res = await _api.get(ApiConstants.salarySheet);
    final list = res['sheets'];
    if (list is List) {
      return list.map((s) => SalarySheetModel.fromJson(Map<String, dynamic>.from(s))).toList();
    }
    return [];
  }

  /// Admin/SuperAdmin — uploads a salary CSV for the whole company for a
  /// given month/year, matching the web app's SalarySheet.jsx exactly.
  /// Required CSV headers: EmpId, Email, Name, Position, Gross Salary,
  /// Attendance, Total Absent, In Hand Salary, Ptax, Remarks.
  Future<void> uploadSalarySheetCsv({
    required File csvFile,
    required int month,
    required int year,
    String title = '',
  }) async {
    final formData = FormData.fromMap({
      'month': month,
      'year': year,
      'title': title,
      'file': await MultipartFile.fromFile(csvFile.path, filename: csvFile.path.split('/').last),
    });
    await ApiClient.instance.dio.post(ApiConstants.salarySheetUpload, data: formData);
  }

  Future<void> deleteSalarySheet(String id) async {
    await _api.delete(ApiConstants.salarySheetDelete(id));
  }

  /// Downloads a payslip to a local temp file. The endpoint requires the
  /// Bearer auth header and streams a local file — it's not a public
  /// Cloudinary URL — so this must go through the authenticated Dio
  /// instance rather than a plain url_launcher open.
  Future<File> downloadPayslip(String payslipId, String fileName) async {
    try {
      final response = await ApiClient.instance.dio.get(
        ApiConstants.downloadPayslip(payslipId),
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final safeName = fileName.isNotEmpty ? fileName : 'payslip_$payslipId.pdf';
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(response.data as List<int>);
      return file;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data is Map ? (e.response!.data['message']?.toString() ?? 'Download failed.') : 'Download failed.',
      );
    }
  }
}