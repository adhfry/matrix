import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_config_model.dart';
import '../../data/repositories/attendance_repository.dart';

final attendanceConfigProvider = FutureProvider.autoDispose<AttendanceConfigModel>((ref) async {
  final repository = ref.watch(attendanceRepositoryProvider);
  return await repository.getAttendanceConfig();
});
