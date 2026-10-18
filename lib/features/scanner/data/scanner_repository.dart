import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Kolom pasien hasil OCR, memakai nama kolom tabel `patients` SiLAKES.
class KtpFields {
  KtpFields(Map<String, String?> values) : values = Map.of(values);

  static const keys = [
    'nik',
    'name',
    'tempat_lahir',
    'tgl_lahir',
    'gender',
    'golongan_darah',
    'alamat',
    'rt_rw',
    'kel_desa',
    'kecamatan',
    'agama',
    'status_perkawinan',
    'pekerjaan',
  ];

  final Map<String, String?> values;

  String? operator [](String k) => values[k];

  factory KtpFields.fromJson(Map<String, dynamic> j) =>
      KtpFields({for (final k in keys) k: J.s(j[k])});
  factory KtpFields.empty() => KtpFields({for (final k in keys) k: null});
}

class KtpCheck {
  const KtpCheck({
    required this.field,
    required this.isError,
    required this.message,
  });
  final String field;
  final bool isError;
  final String message;

  factory KtpCheck.fromJson(Map<String, dynamic> j) => KtpCheck(
    field: J.s(j['field']) ?? '',
    isError: J.s(j['level']) == 'error',
    message: J.s(j['message']) ?? '',
  );
}

class ExistingPatient {
  const ExistingPatient({
    required this.id,
    required this.noReg,
    required this.name,
    this.registeredAt,
  });
  final int id;
  final String noReg;
  final String name;
  final String? registeredAt;

  factory ExistingPatient.fromJson(Map<String, dynamic> j) => ExistingPatient(
    id: J.i(j['id']),
    noReg: J.s(j['no_reg']) ?? '-',
    name: J.s(j['name']) ?? '-',
    registeredAt: J.s(j['registered_at']),
  );
}

class OcrResult {
  const OcrResult({required this.fields, required this.checks, this.existing});
  final KtpFields fields;
  final List<KtpCheck> checks;
  final ExistingPatient? existing;
}

class SavedPatient {
  const SavedPatient({
    required this.id,
    required this.noReg,
    required this.name,
    required this.nikMasked,
    this.createdAt,
    this.gender,
  });
  final int id;
  final String noReg;
  final String name;
  final String nikMasked;
  final DateTime? createdAt;
  final String? gender;

  factory SavedPatient.fromJson(Map<String, dynamic> j) => SavedPatient(
    id: J.i(j['id']),
    noReg: J.s(j['no_reg']) ?? '-',
    name: J.s(j['name']) ?? '-',
    nikMasked: J.s(j['nik_masked']) ?? '',
    createdAt: J.dt(j['created_at']),
    gender: J.s(j['gender']),
  );
}

class ScannerRepository {
  ScannerRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<OcrResult> ocr(File image, {ProgressCallback? onSendProgress}) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: 'ktp.jpg'),
    });
    final d = J.m(
      await _api.post(
        '$_p/scanner/ocr',
        data: form,
        onSendProgress: onSendProgress,
      ),
    );
    return OcrResult(
      fields: KtpFields.fromJson(J.m(d['fields'])),
      checks: J.l(d['checks']).map(KtpCheck.fromJson).toList(),
      existing: d['existing'] is Map
          ? ExistingPatient.fromJson(J.m(d['existing']))
          : null,
    );
  }

  Future<ExistingPatient?> checkNik(String nik) async {
    final d = J.m(await _api.get('$_p/scanner/nik/$nik'));
    return J.b(d['registered']) && d['patient'] is Map
        ? ExistingPatient.fromJson(J.m(d['patient']))
        : null;
  }

  Future<SavedPatient> save(
    Map<String, Object?> payload, {
    File? ktpPhoto,
  }) async {
    final body = Map<String, Object?>.of(payload)
      ..removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
    if (ktpPhoto != null) {
      body['foto_ktp_base64'] =
          'data:image/jpeg;base64,${base64Encode(await ktpPhoto.readAsBytes())}';
    }
    return SavedPatient.fromJson(
      J.m(await _api.post('$_p/scanner/patients', data: body)),
    );
  }

  Future<List<SavedPatient>> mine() async => J
      .l(await _api.get('$_p/scanner/patients'))
      .map(SavedPatient.fromJson)
      .toList();
}

final scannerRepositoryProvider = Provider<ScannerRepository>(
  (ref) => ScannerRepository(ref.watch(apiClientProvider)),
);

final myScannedPatientsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(scannerRepositoryProvider).mine(),
);
