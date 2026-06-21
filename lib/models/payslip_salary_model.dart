class PayslipModel {
  final String id;
  final int year;
  final int month;
  final String fileName;
  final String note;

  PayslipModel({
    required this.id,
    required this.year,
    required this.month,
    required this.fileName,
    required this.note,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    return PayslipModel(
      id: (json['_id'] ?? '').toString(),
      year: (json['year'] is num) ? (json['year'] as num).toInt() : 0,
      month: (json['month'] is num) ? (json['month'] as num).toInt() : 1,
      fileName: json['fileName']?.toString() ?? 'payslip',
      note: json['note']?.toString() ?? '',
    );
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get monthLabel => '${_monthNames[month.clamp(1, 12)]} $year';
}

class SalaryRow {
  final String empId;
  final String email;
  final String name;
  final String position;
  final String grossSalary;
  final String attendance;
  final String totalAbsent;
  final String inHandSalary;
  final String ptax;
  final String remarks;

  SalaryRow({
    required this.empId,
    required this.email,
    required this.name,
    required this.position,
    required this.grossSalary,
    required this.attendance,
    required this.totalAbsent,
    required this.inHandSalary,
    required this.ptax,
    required this.remarks,
  });

  factory SalaryRow.fromJson(Map<String, dynamic> json) {
    return SalaryRow(
      empId: json['empId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      grossSalary: json['grossSalary']?.toString() ?? '',
      attendance: json['attendance']?.toString() ?? '',
      totalAbsent: json['totalAbsent']?.toString() ?? '',
      inHandSalary: json['inHandSalary']?.toString() ?? '',
      ptax: json['ptax']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
    );
  }
}

class SalarySheetModel {
  final String id;
  final int year;
  final int month;
  final String title;
  final List<SalaryRow> rows;

  SalarySheetModel({
    required this.id,
    required this.year,
    required this.month,
    required this.title,
    required this.rows,
  });

  factory SalarySheetModel.fromJson(Map<String, dynamic> json) {
    return SalarySheetModel(
      id: (json['_id'] ?? '').toString(),
      year: (json['year'] is num) ? (json['year'] as num).toInt() : 0,
      month: (json['month'] is num) ? (json['month'] as num).toInt() : 1,
      title: json['title']?.toString() ?? '',
      rows: (json['rows'] is List)
          ? (json['rows'] as List).map((r) => SalaryRow.fromJson(Map<String, dynamic>.from(r))).toList()
          : [],
    );
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get monthLabel => '${_monthNames[month.clamp(1, 12)]} $year';
}
