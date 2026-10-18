import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import 'kinerja_models.dart';

class KinerjaRepository {
  KinerjaRepository(this._api);

  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<KinerjaMonth> month(DateTime m) async {
    final data = await _api.get(
      '$_p/my-matrix/month',
      query: {'year': m.year, 'month': m.month},
    );
    return KinerjaMonth.fromJson(DateTime(m.year, m.month), J.m(data));
  }

  Future<List<MonthSummary>> year(int year) async {
    final data = J.m(
      await _api.get('$_p/my-matrix/summary', query: {'year': year}),
    );
    return J
        .l(data['months'])
        .map((e) => MonthSummary.fromJson(year, e))
        .toList();
  }

  /// Unduh slip PDF ke folder sementara aplikasi lalu kembalikan berkasnya.
  Future<File> slip(int payrollId, DateTime month) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/slip-jaspel-${month.year}-${month.month.toString().padLeft(2, '0')}.pdf',
    );
    await _api.download('$_p/my-matrix/slip/$payrollId', file.path);
    return file;
  }

  /// Ajukan klaim jaspel yang sudah dipublikasikan.
  Future<String> claim(int payrollId) async {
    final res = await _api.postWithMessage(
      '$_p/jaspel/request',
      data: {'payroll_id': payrollId},
    );
    return res.message ?? 'Klaim terkirim. Menunggu persetujuan admin.';
  }

  /// Jaspel bulan lalu yang sudah dipublikasikan tetapi belum diklaim.
  Future<List<({int id, DateTime month, double amount})>> unclaimed() async => J
      .l(await _api.get('$_p/jaspel/unclaimed'))
      .map(
        (p) => (
          id: J.i(p['id']),
          month: Fmt.period(J.s(p['month_year'])) ?? DateTime.now(),
          amount: J.d(p['final_salary']),
        ),
      )
      .toList();

  /// Kelayakan klaim untuk bulan berjalan (aturan waktu dari server).
  Future<({bool eligible, String message})> checkCurrent() async {
    final d = J.m(await _api.get('$_p/jaspel/check'));
    return (eligible: J.b(d['eligible']), message: J.s(d['message']) ?? '');
  }
}

final kinerjaRepositoryProvider = Provider<KinerjaRepository>(
  (ref) => KinerjaRepository(ref.watch(apiClientProvider)),
);

final kinerjaMonthProvider = FutureProvider.autoDispose
    .family<KinerjaMonth, DateTime>(
      (ref, m) => ref.watch(kinerjaRepositoryProvider).month(m),
    );

final kinerjaYearProvider = FutureProvider.autoDispose
    .family<List<MonthSummary>, int>(
      (ref, y) => ref.watch(kinerjaRepositoryProvider).year(y),
    );

final unclaimedJaspelProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(kinerjaRepositoryProvider).unclaimed(),
);
