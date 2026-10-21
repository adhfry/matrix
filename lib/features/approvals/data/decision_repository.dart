import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Hasil lab atau worksheet yang menunggu keputusan admin.
class DecisionItem {
  const DecisionItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.pending,
    this.by,
    this.at,
    this.decided,
    this.webUrl,
  });

  final String kind;
  final int id;
  final String title;
  final String subtitle;
  final String? by;
  final DateTime? at;
  final bool pending;

  /// Kalimat siapa & kapan memutuskan, bila sudah tidak menunggu.
  final String? decided;
  final String? webUrl;

  bool get isWorksheet => kind == DecisionRepository.worksheet;

  factory DecisionItem.fromJson(Map<String, dynamic> j) => DecisionItem(
    kind: J.s(j['kind']) ?? DecisionRepository.labResult,
    id: J.i(j['id']),
    title: J.s(j['title']) ?? '',
    subtitle: J.s(j['subtitle']) ?? '',
    by: J.s(j['by']),
    at: J.dt(j['at'])?.toLocal(),
    pending: j['pending'] == true,
    decided: J.s(j['decided']),
    webUrl: J.s(j['web_url']),
  );
}

/// Keputusan sudah diambil admin lain (HTTP 409); [message] menyebut siapa.
class DecisionTaken implements Exception {
  DecisionTaken(this.message);
  final String message;

  @override
  String toString() => message;
}

class DecisionRepository {
  DecisionRepository(this._api);
  final ApiClient _api;

  static const labResult = 'lab_result';
  static const worksheet = 'worksheet';
  static const _base = '${ApiClient.prefix}/decisions';

  Future<DecisionItem> summary(String kind, int id) async =>
      DecisionItem.fromJson(J.m(await _api.get('$_base/$kind/$id')));

  /// [source] "notification" bila dari tombol notifikasi, "app" bila dari layar.
  Future<String> decide(
    String kind,
    int id, {
    required bool approve,
    String? reason,
    String source = 'app',
  }) async {
    try {
      final r = await _api.postWithMessage(
        _base,
        data: {
          'kind': kind,
          'id': id,
          'decision': approve ? 'approve' : 'reject',
          'reason': ?reason,
          'source': source,
        },
      );
      return r.message ?? (approve ? 'Disetujui.' : 'Ditolak.');
    } on ApiException catch (e) {
      if (e.statusCode == 409) throw DecisionTaken(e.message);
      rethrow;
    }
  }
}

final decisionRepositoryProvider = Provider<DecisionRepository>(
  (ref) => DecisionRepository(ref.watch(apiClientProvider)),
);
