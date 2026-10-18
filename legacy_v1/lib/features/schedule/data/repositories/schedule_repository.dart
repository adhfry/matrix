import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/schedule_model.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

class ScheduleRepository {
  final DioClient _dioClient = DioClient();

  Future<List<ScheduleModel>> getMySchedule({int? month, int? year}) async {
    try {
      String url = '${AppConstants.apiPrefix}/schedule/my';
      if (month != null && year != null) {
        url += '?month=$month&year=$year';
      }
      
      final response = await _dioClient.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        final schedules = (response.data['data']['schedules'] as List)
            .map((json) => ScheduleModel.fromJson(json))
            .toList();
        return schedules;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat jadwal');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> getTeamSchedule() async {
    try {
      final response = await _dioClient.get('${AppConstants.apiPrefix}/schedule/team');
      
      if (response.statusCode == 200 && response.data != null) {
        final users = (response.data['data']['users'] as List)
            .map((json) => TeamMemberSchedule.fromJson(json))
            .toList();
        
        final dateHeaders = (response.data['data']['date_headers'] as List)
            .map((json) => DateHeader.fromJson(json))
            .toList();
        
        return {
          'users': users,
          'date_headers': dateHeaders,
          'period': response.data['data']['period'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat jadwal tim');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ScheduleStats> getScheduleStats() async {
    try {
      final response = await _dioClient.get('${AppConstants.apiPrefix}/schedule/stats');
      
      if (response.statusCode == 200 && response.data != null) {
        return ScheduleStats.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat statistik');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
