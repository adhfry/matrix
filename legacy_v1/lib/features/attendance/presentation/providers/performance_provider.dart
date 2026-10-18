import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/performance_model.dart';
import '../../data/repositories/performance_repository.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  return PerformanceRepository();
});

// Provider dengan parameter (month, year)
final performanceStatsProvider = FutureProvider.autoDispose.family<PerformanceStatsModel, (int, int)>((ref, params) async {
  final repository = ref.watch(performanceRepositoryProvider);
  final (month, year) = params;
  return await repository.getPerformanceStats(month: month, year: year);
});
