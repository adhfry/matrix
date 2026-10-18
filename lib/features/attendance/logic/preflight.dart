import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_client.dart';
import '../data/attendance_models.dart';

enum CheckState { pending, ok, warn, fail }

enum CheckId { camera, location, gps, points, position, radius, map }

class CheckItem {
  const CheckItem(
    this.id,
    this.state,
    this.title,
    this.detail, {
    this.actionLabel,
  });
  final CheckId id;
  final CheckState state;
  final String title;
  final String detail;
  final String? actionLabel;
}

/// Pra-cek sebelum kamera dibuka (permintaan pemilik 2026-10-18): izin kamera,
/// izin lokasi, GPS, titik absen dari server, posisi & akurasi, radius titik
/// terdekat, dan peta. Izin diminta BERURUTAN (dua dialog sekaligus membuat
/// yang kedua hilang di Android).
class AttendancePreflight extends ChangeNotifier {
  AttendancePreflight({
    required this.loadLocations,
    required this.locationFree,
    required this.radiusRequired,
  });

  final Future<List<AttendanceLocation>> Function() loadLocations;

  /// Pegawai bebas lokasi (WFA): radius tidak dicek.
  final bool locationFree;

  /// False untuk pulang lebih awal: lokasi dicatat tetapi bebas radius.
  final bool radiusRequired;

  /// Akurasi GPS lebih buruk dari ini diberi peringatan (bukan penolakan).
  static const accuracyWarnMeters = 50.0;

  PermissionStatus? camera;
  LocationPermission? location;
  bool? gpsOn;
  List<AttendanceLocation>? locations;
  String? pointsError;
  Position? position;
  String? positionError;
  bool mapReady = false;
  bool mapTilesFailed = false;

  StreamSubscription<Position>? _sub;
  bool _disposed = false;

  AttendanceLocation? get nearest {
    final l = locations;
    if (l == null || l.isEmpty || position == null) return null;
    return l.reduce(
      (a, b) => (a.distance ?? 1e12) <= (b.distance ?? 1e12) ? a : b,
    );
  }

  bool get mocked => position?.isMocked ?? false;

  bool get inRange =>
      locationFree || !radiusRequired || (nearest?.inRange ?? false);

  /// Semua syarat wajib terpenuhi -> kamera boleh dibuka.
  bool get ready =>
      camera?.isGranted == true &&
      _locationGranted &&
      gpsOn == true &&
      locations != null &&
      position != null &&
      !mocked &&
      inRange;

  bool get _locationGranted =>
      location == LocationPermission.always ||
      location == LocationPermission.whileInUse;

  Future<void> start() async {
    unawaited(_loadPoints());
    await requestCamera();
    await requestLocation();
  }

  Future<void> requestCamera() async {
    camera = await Permission.camera.request();
    _notify();
  }

  Future<void> requestLocation() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    location = p;
    gpsOn = await Geolocator.isLocationServiceEnabled();
    _notify();
    if (_locationGranted && gpsOn == true) _listen();
  }

  Future<void> openGpsSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Dipanggil saat aplikasi kembali dari pengaturan.
  Future<void> recheck() async {
    camera = await Permission.camera.status;
    location = await Geolocator.checkPermission();
    gpsOn = await Geolocator.isLocationServiceEnabled();
    _notify();
    if (_locationGranted && gpsOn == true && _sub == null) _listen();
  }

  Future<void> _loadPoints() async {
    pointsError = null;
    _notify();
    try {
      locations = await loadLocations();
      if (position != null) _measure(position!);
    } on ApiException catch (e) {
      pointsError = e.message;
    }
    _notify();
  }

  Future<void> retryPoints() => _loadPoints();

  void _listen() {
    _sub?.cancel();
    positionError = null;
    // Ambil cepat posisi terakhir supaya peta & radius langsung terisi.
    Geolocator.getLastKnownPosition()
        .then((p) {
          if (p != null && position == null) _onPosition(p);
        })
        .catchError((Object _) {});
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2,
          ),
        ).listen(
          _onPosition,
          onError: (Object e) {
            positionError = 'Lokasi tidak terbaca. Pindah ke area terbuka.';
            _notify();
          },
        );
  }

  void _onPosition(Position p) {
    position = p;
    positionError = null;
    _measure(p);
    _notify();
  }

  void _measure(Position p) {
    final l = locations;
    if (l == null) return;
    locations =
        l
            .map(
              (x) => x.withDistance(
                Geolocator.distanceBetween(
                  p.latitude,
                  p.longitude,
                  x.latitude,
                  x.longitude,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.distance!.compareTo(b.distance!));
  }

  void markMapReady() {
    if (mapReady) return;
    mapReady = true;
    _notify();
  }

  void markTilesFailed() {
    if (mapTilesFailed) return;
    mapTilesFailed = true;
    _notify();
  }

  /// Arah (derajat dari utara, 0-360) dari posisi pegawai ke titik terdekat.
  double? bearingToNearest() {
    final n = nearest;
    final p = position;
    if (n == null || p == null) return null;
    return (Geolocator.bearingBetween(
              p.latitude,
              p.longitude,
              n.latitude,
              n.longitude,
            ) +
            360) %
        360;
  }

  /// Arah dari posisi pegawai ke titik terdekat, dalam mata angin.
  String? directionToNearest() {
    final n = nearest;
    final p = position;
    if (n == null || p == null) return null;
    final b =
        (Geolocator.bearingBetween(
              p.latitude,
              p.longitude,
              n.latitude,
              n.longitude,
            ) +
            360) %
        360;
    const names = [
      'utara',
      'timur laut',
      'timur',
      'tenggara',
      'selatan',
      'barat daya',
      'barat',
      'barat laut',
    ];
    return names[((b + 22.5) % 360 ~/ 45)];
  }

  List<CheckItem> items() {
    String meters(double d) =>
        d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
    final out = <CheckItem>[];

    out.add(switch (camera) {
      null => const CheckItem(
        CheckId.camera,
        CheckState.pending,
        'Izin kamera',
        'Meminta izin…',
      ),
      final s when s.isGranted => const CheckItem(
        CheckId.camera,
        CheckState.ok,
        'Izin kamera',
        'Diizinkan',
      ),
      final s when s.isPermanentlyDenied => const CheckItem(
        CheckId.camera,
        CheckState.fail,
        'Izin kamera',
        'Ditolak permanen. Izinkan dari pengaturan aplikasi.',
        actionLabel: 'Buka pengaturan',
      ),
      _ => const CheckItem(
        CheckId.camera,
        CheckState.fail,
        'Izin kamera',
        'Dibutuhkan untuk foto wajah.',
        actionLabel: 'Izinkan',
      ),
    });

    out.add(switch (location) {
      null => const CheckItem(
        CheckId.location,
        CheckState.pending,
        'Izin lokasi',
        'Menunggu izin kamera selesai…',
      ),
      LocationPermission.always ||
      LocationPermission.whileInUse => const CheckItem(
        CheckId.location,
        CheckState.ok,
        'Izin lokasi',
        'Diizinkan',
      ),
      LocationPermission.deniedForever => const CheckItem(
        CheckId.location,
        CheckState.fail,
        'Izin lokasi',
        'Ditolak permanen. Izinkan dari pengaturan aplikasi.',
        actionLabel: 'Buka pengaturan',
      ),
      _ => const CheckItem(
        CheckId.location,
        CheckState.fail,
        'Izin lokasi',
        'Dibutuhkan untuk mencatat lokasi absen.',
        actionLabel: 'Izinkan',
      ),
    });

    out.add(switch (gpsOn) {
      null => const CheckItem(
        CheckId.gps,
        CheckState.pending,
        'GPS',
        'Memeriksa…',
      ),
      true => const CheckItem(CheckId.gps, CheckState.ok, 'GPS', 'Aktif'),
      false => const CheckItem(
        CheckId.gps,
        CheckState.fail,
        'GPS',
        'Mati. Nyalakan lokasi di HP.',
        actionLabel: 'Nyalakan GPS',
      ),
    });

    if (pointsError != null) {
      out.add(
        CheckItem(
          CheckId.points,
          CheckState.fail,
          'Titik absen',
          pointsError!,
          actionLabel: 'Muat ulang',
        ),
      );
    } else if (locations == null) {
      out.add(
        const CheckItem(
          CheckId.points,
          CheckState.pending,
          'Titik absen',
          'Memuat dari server…',
        ),
      );
    } else if (locations!.isEmpty && !locationFree) {
      out.add(
        const CheckItem(
          CheckId.points,
          CheckState.fail,
          'Titik absen',
          'Akun Anda belum diberi titik absen. Hubungi admin.',
        ),
      );
    } else {
      out.add(
        CheckItem(
          CheckId.points,
          CheckState.ok,
          'Titik absen',
          locationFree
              ? 'Bebas lokasi'
              : '${locations!.length} titik diizinkan',
        ),
      );
    }

    final p = position;
    if (p == null) {
      out.add(
        CheckItem(
          CheckId.position,
          positionError == null ? CheckState.pending : CheckState.fail,
          'Posisi Anda',
          positionError ?? 'Mencari sinyal GPS…',
        ),
      );
    } else if (p.isMocked) {
      out.add(
        const CheckItem(
          CheckId.position,
          CheckState.fail,
          'Posisi Anda',
          'Terdeteksi lokasi palsu (aplikasi pemalsu GPS). Matikan lalu coba lagi.',
        ),
      );
    } else {
      final acc = p.accuracy;
      out.add(
        CheckItem(
          CheckId.position,
          acc > accuracyWarnMeters ? CheckState.warn : CheckState.ok,
          'Posisi Anda',
          acc > accuracyWarnMeters
              ? 'Akurasi ±${acc.round()} m, kurang tepat. Tunggu sebentar di area terbuka.'
              : 'Akurasi ±${acc.round()} m',
        ),
      );
    }

    final n = nearest;
    if (locationFree) {
      out.add(
        const CheckItem(
          CheckId.radius,
          CheckState.ok,
          'Radius lokasi',
          'Tidak dibatasi untuk akun Anda',
        ),
      );
    } else if (!radiusRequired) {
      out.add(
        CheckItem(
          CheckId.radius,
          CheckState.ok,
          'Radius lokasi',
          n == null
              ? 'Bebas radius untuk pulang lebih awal'
              : 'Bebas radius; terdekat ${n.name} (${meters(n.distance ?? 0)})',
        ),
      );
    } else if (n == null) {
      out.add(
        const CheckItem(
          CheckId.radius,
          CheckState.pending,
          'Radius lokasi',
          'Menunggu posisi & titik absen…',
        ),
      );
    } else if (n.inRange) {
      out.add(
        CheckItem(
          CheckId.radius,
          CheckState.ok,
          'Radius lokasi',
          '${n.name}: ${meters(n.distance!)} dari titik (batas ${n.radiusMeters} m)',
        ),
      );
    } else {
      final dir = directionToNearest();
      out.add(
        CheckItem(
          CheckId.radius,
          CheckState.fail,
          'Radius lokasi',
          'Di luar radius ${n.name}: ${meters(n.distance!)}${dir == null ? '' : ' ke arah $dir'}, batas ${n.radiusMeters} m.',
          actionLabel: 'Buka navigasi',
        ),
      );
    }

    out.add(
      CheckItem(
        CheckId.map,
        mapTilesFailed
            ? CheckState.warn
            : (mapReady ? CheckState.ok : CheckState.pending),
        'Peta',
        mapTilesFailed
            ? 'Gambar peta gagal dimuat; absen tetap bisa'
            : (mapReady ? 'Siap' : 'Menyiapkan…'),
      ),
    );
    return out;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  @visibleForTesting
  void debugSet({
    PermissionStatus? cam,
    LocationPermission? loc,
    bool? gps,
    List<AttendanceLocation>? points,
    Position? pos,
  }) {
    camera = cam ?? camera;
    location = loc ?? location;
    gpsOn = gps ?? gpsOn;
    if (points != null) locations = points;
    if (pos != null) _onPosition(pos);
  }
}
