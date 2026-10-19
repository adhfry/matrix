import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format/fmt.dart';
import '../storage/secure_store.dart';

/// Server API. Bisa diganti saat build: `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.silakes.labkesdasumenep.id',
);

/// Galat dari API yang sudah diterjemahkan ke kalimat untuk pegawai.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;

  /// Galat per kolom dari validasi Laravel (`{field: [pesan]}`).
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isOffline => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._store) {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.headers.containsKey('Authorization')) {
            final token = await _store.token();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (e, handler) {
          // 401 dari endpoint selain logout = token ditolak -> sesi berakhir.
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.endsWith('/mobile/logout')) {
            _unauthorized.add(null);
          }
          handler.next(e);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (o) => debugPrint('[api] $o'),
        ),
      );
    }
  }

  final SecureStore _store;
  late final Dio _dio;
  final _unauthorized = StreamController<void>.broadcast();

  /// Dipancarkan saat token ditolak server (sesi berakhir / login di HP lain).
  Stream<void> get onUnauthorized => _unauthorized.stream;

  @visibleForTesting
  void debugEmitUnauthorized() => _unauthorized.add(null);

  static const prefix = '/api/app/v1/matrix';

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(
    String path, {
    Object? data,
    ProgressCallback? onSendProgress,
  }) => _send(
    () => _dio.post<dynamic>(path, data: data, onSendProgress: onSendProgress),
  );

  /// Seperti [post] tetapi ikut mengembalikan `message` server (mis. "Terlambat 4 menit").
  Future<({dynamic data, String? message})> postWithMessage(
    String path, {
    Object? data,
  }) async {
    String? message;
    final result = await _send(() async {
      final res = await _dio.post<dynamic>(path, data: data);
      if (res.data is Map) message = J.s((res.data as Map)['message']);
      return res;
    });
    return (data: result, message: message);
  }

  /// PUT dengan pesan server (dipakai simpan data diri).
  Future<({dynamic data, String? message})> putWithMessage(
    String path, {
    Object? data,
  }) async {
    String? message;
    final result = await _send(() async {
      final res = await _dio.put<dynamic>(path, data: data);
      if (res.data is Map) message = J.s((res.data as Map)['message']);
      return res;
    });
    return (data: result, message: message);
  }

  /// Cabut token di server dengan token yang sudah disimpan sebelumnya
  /// (dipakai saat keluar: sesi lokal sudah dihapus lebih dulu).
  Future<void> revoke(String token) async {
    try {
      await _dio.post<dynamic>(
        '$prefix/mobile/logout',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
    } on DioException {
      // Tidak masalah bila gagal: token lokal sudah dihapus.
    }
  }

  /// Unduh berkas biner (mis. slip PDF) ke [savePath].
  Future<void> download(String path, String savePath) async {
    try {
      await _dio.download(path, savePath);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// Berkas biner ke memori (mis. surat izin PDF untuk pratinjau & dibagikan).
  Future<Uint8List> bytes(String path) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<dynamic> delete(String path, {Object? data}) =>
      _send(() => _dio.delete<dynamic>(path, data: data));

  /// GET yang mengembalikan amplop utuh `{data, meta, message}` (untuk paginasi).
  Future<Map<String, dynamic>> getEnvelope(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    Map<String, dynamic> envelope = const {};
    await _send(() async {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      if (res.data is Map) envelope = J.m(res.data);
      return res;
    });
    return envelope;
  }

  /// Membuka amplop `{status, data, message}` SiLAKES. Melempar [ApiException]
  /// kalau `status == error` walau HTTP 200 (beberapa endpoint lama begitu).
  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map && (body['status'] == 'error' || body['error'] == true)) {
        throw ApiException(
          _messageOf(body) ?? 'Permintaan ditolak server.',
          statusCode: res.statusCode,
        );
      }
      return body is Map && body.containsKey('data') ? body['data'] : body;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Server terlalu lama merespons. Periksa sinyal lalu coba lagi.',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          'Tidak ada koneksi internet. Sambungkan data/Wi-Fi lalu coba lagi.',
        );
      case DioExceptionType.cancel:
        return ApiException('Permintaan dibatalkan.');
      default:
        break;
    }
    final status = e.response?.statusCode;
    final body = e.response?.data;
    if (status == 401) {
      return ApiException(
        'Sesi Anda berakhir. Silakan masuk lagi.',
        statusCode: 401,
      );
    }
    final fields = <String, String>{};
    if (body is Map) {
      final errors =
          body['errors'] ?? (body['data'] is Map ? body['data'] : null);
      if (errors is Map) {
        errors.forEach((k, v) {
          if (v is List && v.isNotEmpty) fields['$k'] = '${v.first}';
        });
      }
    }
    final msg = body is Map ? _messageOf(body) : null;
    if (status != null && status >= 500) {
      return ApiException(
        'Server sedang bermasalah ($status). Coba beberapa saat lagi.',
        statusCode: status,
      );
    }
    return ApiException(
      msg ??
          (fields.isNotEmpty
              ? fields.values.first
              : 'Terjadi kesalahan ($status).'),
      statusCode: status,
      fieldErrors: fields,
    );
  }

  static String? _messageOf(Map<dynamic, dynamic> body) {
    final m = body['message'];
    if (m is String &&
        m.isNotEmpty &&
        m != 'Validation Error' &&
        m != 'Invalid Data') {
      return m;
    }
    // Laravel kadang menaruh galat validasi di `message` sebagai map.
    if (m is Map && m.isNotEmpty) {
      final first = m.values.first;
      return first is List && first.isNotEmpty ? '${first.first}' : '$first';
    }
    final data = body['data'];
    if (data is Map && data.isNotEmpty) {
      final first = data.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
    }
    return m is String && m.isNotEmpty ? m : null;
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStoreProvider)),
);
