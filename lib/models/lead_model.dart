/// Callback, Sale, and Transfer all share the exact same Mongoose schema
/// shape on the backend (employeeName, employeeEmail, name, email, phone,
/// domainName, address, country, zipcode, comments, buget, calldate,
/// createdDate, user_id, timestamps). One model + one parameterised
/// service covers all three resources.
class LeadModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String domainName;
  final String address;
  final String country;
  final String zipcode;
  final String comments;
  final String budget; // backend field is literally spelled "buget"
  final String callDate;
  final String? transferTo; // Sale + Transfer only
  final DateTime createdAt;

  LeadModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.domainName,
    required this.address,
    required this.country,
    required this.zipcode,
    required this.comments,
    required this.budget,
    required this.callDate,
    this.transferTo,
    required this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return LeadModel(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      domainName: json['domainName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      zipcode: json['zipcode']?.toString() ?? '',
      comments: json['comments']?.toString() ?? '',
      budget: json['buget']?.toString() ?? '',
      callDate: json['calldate']?.toString() ?? '',
      transferTo: json['transferTo']?.toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'domainName': domainName,
        'address': address,
        'country': country,
        'zipcode': zipcode,
        'comments': comments,
        'buget': budget,
        'calldate': callDate,
      };
}

enum LeadType { callback, sale, transfer }

extension LeadTypeX on LeadType {
  /// Mount path segment used by the backend routes.
  String get path {
    switch (this) {
      case LeadType.callback:
        return 'callback';
      case LeadType.sale:
        return 'sale';
      case LeadType.transfer:
        return 'transfer';
    }
  }

  String get label {
    switch (this) {
      case LeadType.callback:
        return 'Callback';
      case LeadType.sale:
        return 'Sale';
      case LeadType.transfer:
        return 'Transfer';
    }
  }

  /// The field name the backend embeds leads under when an admin looks up
  /// ONE employee's leads (GET /:type/user/:id). Inconsistent on the
  /// backend — callback/transfer use the singular path name, but sale's
  /// aggregation embeds under "sales" (plural).
  String get embeddedField {
    switch (this) {
      case LeadType.callback:
        return 'callback';
      case LeadType.sale:
        return 'sales';
      case LeadType.transfer:
        return 'transfer';
    }
  }
}
