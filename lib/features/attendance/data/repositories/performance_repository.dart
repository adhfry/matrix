import '../../../../core/api/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/performance_model.dart';

class PerformanceRepository {
  final DioClient _dioClient = DioClient();

  Future<PerformanceStatsModel> getPerformanceStats({
    int? month,
    int? year,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      print('🔍 Fetching performance stats for month: $month, year: $year');
      print('📡 Query params: $queryParams');

      final response = await _dioClient.get(
        '${AppConstants.apiPrefix}/performance/stats',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      print('✅ Performance stats response: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        return PerformanceStatsModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat data kinerja');
      }
    } catch (e) {
      print('❌ Error fetching performance stats: $e');
      throw Exception(e.toString());
    }
  }
}
