import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/schedule_model.dart';
import '../../data/repositories/schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

// Provider untuk jadwal 7 hari ke depan
final myScheduleProvider = FutureProvider.autoDispose<List<ScheduleModel>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return await repository.getMySchedule();
});

// Provider untuk jadwal bulanan dengan parameter
final monthlyScheduleProvider = FutureProvider.autoDispose.family<List<ScheduleModel>, (int, int)>((ref, params) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  final (month, year) = params;
  return await repository.getMySchedule(month: month, year: year);
});

final teamScheduleProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return await repository.getTeamSchedule();
});

final scheduleStatsProvider = FutureProvider.autoDispose<ScheduleStats>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return await repository.getScheduleStats();
});
