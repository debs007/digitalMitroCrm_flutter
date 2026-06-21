import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/lead_model.dart';

/// One service handles Callback, Sale, and Transfer since their backend
/// routes and response shapes are identical — only the mount path differs.
class LeadService {
  LeadService._();
  static final LeadService instance = LeadService._();

  final ApiClient _api = ApiClient.instance;

  Future<({List<LeadModel> items, int totalPages, int total})> getMine(
    LeadType type, {
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiConstants.leadMine(type.path),
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = res['data'];
    final items = (list is List) ? list.map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e))).toList() : <LeadModel>[];
    return (
      items: items,
      totalPages: (res['totalPages'] is num) ? (res['totalPages'] as num).toInt() : 1,
      total: (res[_totalKey(type)] is num) ? (res[_totalKey(type)] as num).toInt() : items.length,
    );
  }

  String _totalKey(LeadType type) {
    switch (type) {
      case LeadType.callback:
        return 'totalCallbacks';
      case LeadType.sale:
        return 'totalSales';
      case LeadType.transfer:
        return 'totalTransfer';
    }
  }

  Future<void> create(LeadType type, LeadModel lead) async {
    await _api.post(ApiConstants.leadCreate(type.path), data: lead.toCreateJson());
  }

  /// Admin/SuperAdmin viewing one specific employee's leads — a different
  /// endpoint shape than getMine(): GET /:type/user/:id returns the
  /// employee doc itself with the leads embedded as an array field.
  Future<List<LeadModel>> getForEmployee(LeadType type, String employeeId) async {
    final res = await _api.get(ApiConstants.leadForEmployee(type.path, employeeId));
    final list = res[type.embeddedField];
    if (list is List) {
      return list.map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return [];
  }

  Future<void> delete(LeadType type, String id) async {
    await _api.delete(ApiConstants.leadDelete(type.path, id));
  }
}
