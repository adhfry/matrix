import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import 'attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);

  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<AttendanceConfig> config() async =>
      AttendanceConfig.fromJson(J.m(await _api.get('$_p/attendance/config')));

  Future<TodayActivity> today() async =>
      TodayActivity.fromJson(J.m(await _api.get('$_p/attendance/dashboard')));

  Future<List<AttendanceLocation>> locations() async => J
      .l(await _api.get('$_p/mobile/attendance/locations'))
      .map(AttendanceLocation.fromJson)
      .toList();

  /// Server menentukan sendiri apakah ini absen masuk atau pulang (sesi terbuka).
  Future<String> submit({
    required bool checkOut,
    required double latitude,
    required double longitude,
    required int? locationId,
    required File photo,
  }) async {
    final form = FormData.fromMap({
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'location_id': ?locationId?.toString(),
      'photo': await MultipartFile.fromFile(
        photo.path,
        filename:
            '${checkOut ? 'check_out' : 'check_in'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });
    final res = await _api.postWithMessage(
      '$_p/attendance/${checkOut ? 'check-out' : 'check-in'}',
      data: form,
    );
    return res.message ??
        (checkOut ? 'Check-out tercatat.' : 'Check-in tercatat.');
  }
}

extension EarlyCheckoutApi on AttendanceRepository {
  /// Pulang lebih awal: lokasi bebas, foto + alasan wajib.
  Future<String> earlyCheckout({
    required double latitude,
    required double longitude,
    required File photo,
    required String reason,
  }) async {
    final form = FormData.fromMap({
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'reason': reason,
      'source': 'app',
      'photo': await MultipartFile.fromFile(
        photo.path,
        filename: 'early_checkout_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });
    final res = await _api.postWithMessage(
      '${ApiClient.prefix}/attendance/early-checkout',
      data: form,
    );
    return res.message ?? 'Check-out lebih awal tercatat.';
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(ref.watch(apiClientProvider)),
);

final attendanceConfigProvider = FutureProvider.autoDispose<AttendanceConfig>(
  (ref) => ref.watch(attendanceRepositoryProvider).config(),
);

final todayActivityProvider = FutureProvider.autoDispose<TodayActivity>(
  (ref) => ref.watch(attendanceRepositoryProvider).today(),
);
