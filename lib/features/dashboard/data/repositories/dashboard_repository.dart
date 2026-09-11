import '../../../../core/api/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/dashboard_stats_model.dart';

class DashboardRepository {
  final DioClient _dioClient = DioClient();

  Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final response = await _dioClient.get(AppConstants.attendanceDashboardEndpoint);
      
      if (response.statusCode == 200 && response.data != null) {
        return DashboardStatsModel.fromJson(response.data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load dashboard stats');
      }
    } catch (e) {
      throw Exception('Error fetching dashboard stats: $e');
    }
  }
}
