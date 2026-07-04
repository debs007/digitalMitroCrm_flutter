import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/concern_model.dart';

class ConcernService {
  ConcernService._();
  static final ConcernService instance = ConcernService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<ConcernModel>> getMine() async {
    final res = await _api.get(ApiConstants.myConcerns);
    final list = res['concerns'];
    if (list is List) {
      return list.map((c) => ConcernModel.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  /// Admin/SuperAdmin only — already scope-filtered server-side to only
  /// the employees this admin is allowed to manage.
  Future<List<ConcernModel>> getAll() async {
    final res = await _api.get(ApiConstants.allConcerns);
    final list = res['concerns'];
    if (list is List) {
      return list.map((c) => ConcernModel.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  /// Admin/SuperAdmin only — this endpoint isn't scope-filtered server
  /// side (counts every pending concern company-wide), which is fine
  /// since regular employees aren't shown this badge at all in the
  /// drawer; only an admin can actually action a pending concern.
  Future<int> getPendingCount() async {
    final res = await _api.get(ApiConstants.pendingConcernsCount);
    final count = res['count'];
    return (count is num) ? count.toInt() : 0;
  }

  Future<void> submit({
    required String concernType,
    required String message,
    String? concernDate,
    String? actualPunchIn,
    String? actualPunchOut,
  }) async {
    await _api.post(ApiConstants.submitConcern, data: {
      'concernType': concernType,
      'message': message,
      if (concernDate != null) 'ConcernDate': concernDate,
      if (actualPunchIn != null) 'ActualPunchIn': actualPunchIn,
      if (actualPunchOut != null) 'ActualPunchOut': actualPunchOut,
    });
  }

  Future<void> approve({required String userId, required String concernId}) async {
    await _api.patch(ApiConstants.approveConcern(userId, concernId));
  }

  Future<void> reject({required String userId, required String concernId}) async {
    await _api.patch(ApiConstants.rejectConcern(userId, concernId));
  }
}
