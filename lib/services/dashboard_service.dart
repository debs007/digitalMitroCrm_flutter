import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/dashboard_model.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  final ApiClient _api = ApiClient.instance;

  Future<DashboardData> getDashboard() async {
    final res = await _api.get(ApiConstants.mobileDashboard);
    return DashboardData.fromJson(res);
  }
}
