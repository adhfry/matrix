import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_history_model.dart';
import '../../data/repositories/attendance_history_repository.dart';

final attendanceHistoryRepositoryProvider = Provider<AttendanceHistoryRepository>((ref) {
  return AttendanceHistoryRepository();
});

final attendanceHistoryProvider = FutureProvider.autoDispose.family<AttendanceHistoryModel, (int, int)>((ref, params) async {
  final repository = ref.watch(attendanceHistoryRepositoryProvider);
  final (month, year) = params;
  return await repository.getAttendanceHistory(month: month, year: year);
});
