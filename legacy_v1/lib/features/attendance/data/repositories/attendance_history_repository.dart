import '../../../../core/api/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/attendance_history_model.dart';

class AttendanceHistoryRepository {
  final DioClient _dioClient = DioClient();

  Future<AttendanceHistoryModel> getAttendanceHistory({
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      final response = await _dioClient.get(
        '${AppConstants.apiPrefix}/attendance/history',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return AttendanceHistoryModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat riwayat absensi');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
