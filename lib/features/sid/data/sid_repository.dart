import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Bagian ketentuan SID (judul + butir).
class SidTermsSection {
  const SidTermsSection(this.title, this.items);
  final String title;
  final List<String> items;
}

/// Syarat & Ketentuan SID berversi (sama dengan web, config/sid.php).
class SidTerms {
  const SidTerms({
    required this.version,
    required this.title,
    required this.intro,
    required this.sections,
    required this.agreement,
  });

  factory SidTerms.fromJson(Map<String, dynamic> j) => SidTerms(
    version: J.s(j['version']) ?? '',
    title: J.s(j['title']) ?? 'Syarat & Ketentuan SID',
    intro: J.s(j['intro']) ?? '',
    sections: J
        .l(j['sections'])
        .map(
          (s) => SidTermsSection(
            J.s(s['title']) ?? '',
            (s['items'] is List ? s['items'] as List : const [])
                .map((e) => '$e')
                .toList(),
          ),
        )
        .toList(),
    agreement: J.s(j['agreement']) ?? '',
  );

  final String version;
  final String title;
  final String intro;
  final List<SidTermsSection> sections;
  final String agreement;
}

/// Status SID pegawai: none (belum punya) | needs_terms | active.
class SidStatus {
  const SidStatus({
    required this.state,
    this.id,
    this.createdAt,
    this.createdVia,
    this.termsVersion,
    required this.latestTerms,
    required this.usageCount,
    this.revokedReason,
    this.revokedLegacy = false,
  });

  factory SidStatus.fromJson(Map<String, dynamic> j) {
    final r = j['last_revoked'] is Map ? J.m(j['last_revoked']) : null;
    return SidStatus(
      state: J.s(j['state']) ?? 'none',
      id: J.s(j['id']),
      createdAt: J.dt(j['created_at'])?.toLocal(),
      createdVia: J.s(j['created_via']),
      termsVersion: J.s(j['terms_version']),
      latestTerms: J.s(j['latest_terms']) ?? '',
      usageCount: J.i(j['usage_count']),
      revokedReason: r == null ? null : J.s(r['reason']),
      revokedLegacy: r != null && J.b(r['legacy']),
    );
  }

  final String state;
  final String? id;
  final DateTime? createdAt;
  final String? createdVia;
  final String? termsVersion;
  final String latestTerms;
  final int usageCount;
  final String? revokedReason;
  final bool revokedLegacy;

  bool get active => state == 'active';
  bool get hasSid => state != 'none';
}

class SidOverview {
  const SidOverview(this.status, this.terms);
  final SidStatus status;
  final SidTerms terms;
}

class SidRepository {
  SidRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<SidOverview> overview() async {
    final d = J.m(await _api.get('$_p/sid'));
    return SidOverview(
      SidStatus.fromJson(J.m(d['status'])),
      SidTerms.fromJson(J.m(d['terms'])),
    );
  }

  Future<Uint8List> image() => _api.bytes('$_p/sid/image');

  /// Simpan SID dari PNG kanvas beserta versi ketentuan yang disetujui.
  Future<SidStatus> save(Uint8List png, String termsVersion) async {
    final form = FormData.fromMap({
      'signature': MultipartFile.fromBytes(
        png,
        filename: 'sid.png',
        contentType: DioMediaType('image', 'png'),
      ),
      'terms_version': termsVersion,
      'agree': '1',
      'via': 'matrix',
    });
    final d = J.m(await _api.post('$_p/sid', data: form));
    return SidStatus.fromJson(J.m(d['status']));
  }

  Future<SidStatus> acceptTerms(String termsVersion) async {
    final d = J.m(
      await _api.post(
        '$_p/sid/accept-terms',
        data: {'terms_version': termsVersion, 'agree': 1},
      ),
    );
    return SidStatus.fromJson(J.m(d['status']));
  }
}

final sidRepositoryProvider = Provider<SidRepository>(
  (ref) => SidRepository(ref.watch(apiClientProvider)),
);

final sidOverviewProvider = FutureProvider.autoDispose<SidOverview>(
  (ref) => ref.watch(sidRepositoryProvider).overview(),
);
