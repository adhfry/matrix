import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/leave_request_repository.dart';

final leaveRequestRepositoryProvider = Provider<LeaveRequestRepository>((ref) {
  return LeaveRequestRepository();
});

final leaveRequestProvider = FutureProvider.autoDispose.family<LeaveRequestModel, (int, int)>((ref, params) async {
  final repository = ref.watch(leaveRequestRepositoryProvider);
  final (month, year) = params;
  return await repository.getLeaveRequests(month: month, year: year);
});
