import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Satu kolom data diri. Aturan, opsi, dan kelengkapan ditentukan server
/// (EmployeeIdentityService) supaya app & web selalu sama.
class IdentityField {
  const IdentityField({
    required this.key,
    required this.label,
    required this.section,
    this.value,
    this.declarable = false,
    this.declared = false,
    this.readonly = false,
    this.options,
    this.hint,
  });

  final String key;
  final String label;
  final String section;
  final String? value;
  final bool declarable;
  final bool declared;
  final bool readonly;

  /// Daftar pilihan (List) atau kode->label (Map), null = isian bebas.
  final Object? options;
  final String? hint;

  bool get isDate => key == 'tanggal_lahir';

  Map<String, String>? get optionMap {
    final o = options;
    if (o is Map) return o.map((k, v) => MapEntry('$k', '$v'));
    if (o is List) return {for (final v in o) '$v': '$v'};
    return null;
  }

  factory IdentityField.fromJson(Map<String, dynamic> j) => IdentityField(
    key: J.s(j['key'])!,
    label: J.s(j['label']) ?? '',
    section: J.s(j['section']) ?? '',
    value: J.s(j['value']),
    declarable: J.b(j['declarable']),
    declared: J.b(j['declared']),
    readonly: J.b(j['readonly']),
    options: j['options'],
    hint: J.s(j['hint']),
  );
}

class IdentityData {
  const IdentityData({
    required this.sections,
    required this.fields,
    required this.domisiliSamaKtp,
    required this.completeness,
    required this.missing,
  });

  final Map<String, String> sections;
  final List<IdentityField> fields;
  final bool domisiliSamaKtp;
  final int completeness;
  final List<String> missing;

  bool get complete => completeness >= 100;

  factory IdentityData.fromJson(Map<String, dynamic> j) => IdentityData(
    sections: J.m(j['sections']).map((k, v) => MapEntry(k, '$v')),
    fields: J.l(j['fields']).map(IdentityField.fromJson).toList(),
    domisiliSamaKtp: J.b(j['domisili_sama_ktp']),
    completeness: J.i(j['completeness']),
    missing: (j['missing'] is List)
        ? (j['missing'] as List).map((e) => '$e').toList()
        : const [],
  );
}

class IdentityRepository {
  IdentityRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<IdentityData> get() async =>
      IdentityData.fromJson(J.m(await _api.get('$_p/my-identity')));

  Future<({IdentityData data, String message})> save({
    required Map<String, String?> values,
    required Map<String, bool> declarations,
    required bool domisiliSamaKtp,
  }) async {
    final res = await _api.putWithMessage(
      '$_p/my-identity',
      data: {
        'values': values,
        'declarations': declarations,
        'domisili_sama_ktp': domisiliSamaKtp,
      },
    );
    return (
      data: IdentityData.fromJson(J.m(res.data)),
      message: res.message ?? 'Data diri tersimpan.',
    );
  }
}

final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => IdentityRepository(ref.watch(apiClientProvider)),
);

final identityProvider = FutureProvider.autoDispose<IdentityData>(
  (ref) => ref.watch(identityRepositoryProvider).get(),
);
