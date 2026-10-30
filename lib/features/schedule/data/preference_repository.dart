import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Pilihan pegawai untuk satu tanggal saat jadwal disusun.
enum PrefKind { libur, pagi, siang }

/// Shift pagi/siang yang biasa diterima pegawai (kode + jam), dari server.
class UsualShift {
  const UsualShift(this.code, this.start, this.end);
  final String code;
  final String start; // HH:mm
  final String end;

  String get jam => '${start.replaceAll(':', '.')} sampai ${end.replaceAll(':', '.')}';

  factory UsualShift.fromJson(Map<String, dynamic> j) => UsualShift(
    J.s(j['code']) ?? '',
    J.s(j['start']) ?? '',
    J.s(j['end']) ?? '',
  );
}

class PrefInfo {
  const PrefInfo({required this.pagi, required this.siang, this.windowClosed});
  final UsualShift pagi;
  final UsualShift siang;

  /// Pesan bila pengisian sedang ditutup admin (Pengaturan MATRIX), selain itu null.
  final String? windowClosed;
}

/// Preferensi jadwal (libur + masuk pagi/siang), sama dengan menu web
/// Preferensi Jadwal (SchedulePreferenceController). Kode shift masuk
/// mengikuti yang biasa diterima pegawai, ditentukan server.
class PreferenceRepository {
  PreferenceRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  static String monthKey(DateTime m) =>
      '${m.month.toString().padLeft(2, '0')}-${m.year}';

  Future<PrefInfo> info() async {
    final d = J.m(await _api.get('$_p/preferences/info'));
    final u = J.m(d['usual']);
    return PrefInfo(
      pagi: UsualShift.fromJson(J.m(u['pagi'])),
      siang: UsualShift.fromJson(J.m(u['siang'])),
      windowClosed: J.s(d['window_closed']),
    );
  }

  /// Pilihan bulan [m]: kunci "yyyy-MM-dd".
  Future<Map<String, PrefKind>> month(DateTime m) async {
    final raw = await _api.get(
      '$_p/preferences',
      query: {'month_year': monthKey(m)},
    );
    final out = <String, PrefKind>{};
    if (raw is! Map) return out;
    final d = J.m(raw);
    for (final s in (d['requested_off_dates'] as List? ?? const [])) {
      out['$s'] = PrefKind.libur;
    }
    for (final w in J.l(d['requested_work_shifts'])) {
      final kind = J.s(w['waktu']) == 'siang' ? PrefKind.siang : PrefKind.pagi;
      out[J.s(w['date'])!] = kind;
    }
    return out;
  }

  Future<String?> save(DateTime m, Map<String, PrefKind> picks) async {
    List<String> of(PrefKind k) =>
        (picks.entries.where((e) => e.value == k).map((e) => e.key).toList()..sort());
    final res = await _api.postWithMessage(
      '$_p/preferences',
      data: {
        'month_year': monthKey(m),
        'dates': of(PrefKind.libur),
        'work': [
          for (final d in of(PrefKind.pagi)) {'date': d, 'waktu': 'pagi'},
          for (final d in of(PrefKind.siang)) {'date': d, 'waktu': 'siang'},
        ],
      },
    );
    return res.message;
  }
}

final preferenceRepositoryProvider = Provider<PreferenceRepository>(
  (ref) => PreferenceRepository(ref.watch(apiClientProvider)),
);

final prefInfoProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(preferenceRepositoryProvider).info(),
);
