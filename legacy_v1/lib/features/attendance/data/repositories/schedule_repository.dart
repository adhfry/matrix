import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/api/dio_client.dart';
import '../models/my_schedule_model.dart';

class ScheduleRepository {
  final DioClient _dioClient = DioClient();

  Future<List<MyScheduleModel>> getMySchedule() async {
    try {
      final response = await _dioClient.get('${AppConstants.apiPrefix}/schedule/my');
      
      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        final schedules = (data['schedules'] as List<dynamic>)
            .map((e) => MyScheduleModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return schedules;
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat jadwal');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTeamSchedule() async {
    try {
      final response = await _dioClient.get('${AppConstants.apiPrefix}/schedule/team');
      
      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        
        final users = (data['users'] as List<dynamic>)
            .map((e) => TeamScheduleModel.fromJson(e as Map<String, dynamic>))
            .toList();
            
        final dateHeaders = (data['date_headers'] as List<dynamic>)
            .map((e) => DateHeaderModel.fromJson(e as Map<String, dynamic>))
            .toList();
        
        return {
          'users': users,
          'dateHeaders': dateHeaders,
          'period': data['period'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat jadwal tim');
      }
    } catch (e) {
      rethrow;
    }
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

// Providers for schedule data
final myScheduleProvider = FutureProvider<List<MyScheduleModel>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.getMySchedule();
});

final teamScheduleProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.getTeamSchedule();
});
