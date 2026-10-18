import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStatsModel>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getDashboardStats();
});
