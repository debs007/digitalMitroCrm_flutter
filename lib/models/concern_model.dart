class ConcernModel {
  final String id;
  final String userId;
  final String userName;
  final String concernType;
  final String message;
  final String? concernDate;
  final String? actualPunchIn;
  final String? actualPunchOut;
  final String status; // Pending | Approved | Rejected
  final DateTime createdAt;

  ConcernModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.concernType,
    required this.message,
    this.concernDate,
    this.actualPunchIn,
    this.actualPunchOut,
    required this.status,
    required this.createdAt,
  });

  factory ConcernModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    final userIdRaw = json['user_id'];
    String userId = '';
    String userName = '';
    if (userIdRaw is Map) {
      userId = userIdRaw['_id']?.toString() ?? '';
      userName = userIdRaw['name']?.toString() ?? '';
    } else {
      userId = userIdRaw?.toString() ?? '';
    }

    return ConcernModel(
      id: (json['_id'] ?? '').toString(),
      userId: userId,
      userName: userName,
      concernType: json['concernType']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      concernDate: json['ConcernDate']?.toString(),
      actualPunchIn: json['ActualPunchIn']?.toString(),
      actualPunchOut: json['ActualPunchOut']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      createdAt: parseDate(json['createdAt']),
    );
  }
}
