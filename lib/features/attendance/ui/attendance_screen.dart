import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/widgets/finance.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';
import '../logic/liveness.dart';
import '../logic/preflight.dart';
import 'preflight_view.dart';
import 'voice_guide.dart';

enum _Phase {
  /// Menunggu izin kamera.
  waitCamera,
  starting,
  scanning,
  sending,
  success,
  failed,
  cameraBlocked,
}

/// Absen wajah dengan peta di latar (tata letak v1): kamera bundar di atas,
/// posisi & titik absen di peta, panel lokasi + pemeriksaan di bawah.
/// Kamera langsung terbuka; kedipan baru dihitung setelah semua syarat lokasi
/// terpenuhi, lalu foto diambil otomatis. [early] = pulang lebih awal (bebas
/// radius, alasan sudah diisi sebelumnya). Pesan server dikembalikan lewat pop.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.config,
    this.early = false,
    this.reason,
  });

  final AttendanceConfig config;
  final bool early;
  final String? reason;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with WidgetsBindingObserver {
  late final AttendancePreflight _pre;
  final _mapKey = GlobalKey<AttendanceMapState>();

  CameraController? _camera;
  CameraDescription? _cameraDesc;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final _liveness = LivenessTracker();
  VoiceGuide? _voice;
  bool _detecting = false;
  bool _opening = false;

  /// Aplikasi di latar: kamera dilepas dan tidak boleh dibuka.
  bool _paused = false;

  _Phase _phase = _Phase.waitCamera;
  LivenessStep _step = LivenessStep.noFace;
  bool _faceSeen = false;
  String? _error;
  String? _resultMessage;
  File? _capture;

  String get _title => widget.early
      ? 'Pulang lebih awal'
      : (widget.config.isCheckOut ? 'Check-out' : 'Check-in');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pre = AttendancePreflight(
      loadLocations: ref.read(attendanceRepositoryProvider).locations,
      locationFree: widget.config.isLocationFree,
      radiusRequired: !widget.early,
    )..addListener(_onPreflight);
    _pre.start();
    ref.read(secureStoreProvider).ttsEnabled().then((on) async {
      final v = VoiceGuide(enabled: on);
      await v.init();
      if (mounted) {
        _voice = v;
      } else {
        v.dispose();
      }
    });
  }

  void _onPreflight() {
    if (!mounted) return;
    _maybeOpenCamera();
    setState(() {});
  }

  void _maybeOpenCamera() {
    if (!_paused &&
        _phase == _Phase.waitCamera &&
        _pre.camera?.isGranted == true) {
      unawaited(_openCamera());
    }
  }

  // ---------------- Kamera & wajah ----------------

  Future<void> _openCamera() async {
    if (_opening || _camera != null) return;
    _opening = true;
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    CameraController? ctrl;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'Tidak ada kamera');
      _cameraDesc = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      ctrl = CameraController(
        _cameraDesc!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!mounted || _paused) {
        await ctrl.dispose();
        if (mounted) setState(() => _phase = _Phase.waitCamera);
        return;
      }
      _camera = ctrl;
      _liveness.reset();
      setState(() {
        _phase = _Phase.scanning;
        _step = LivenessStep.noFace;
        _faceSeen = false;
      });
      await ctrl.startImageStream(_onFrame);
      unawaited(
        _voice?.once(
          'welcome',
          'Halo ${widget.config.userName.split(' ').first}, hadapkan wajah anda ke kamera',
        ),
      );
    } on CameraException catch (e) {
      await ctrl?.dispose();
      _camera = null;
      if (!mounted) return;
      setState(() {
        _phase = _Phase.cameraBlocked;
        _error = e.code == 'none'
            ? 'Perangkat ini tidak punya kamera depan.'
            : 'Kamera tidak bisa dibuka (${e.code}). Tutup aplikasi lain yang memakai kamera lalu coba lagi.';
      });
    } finally {
      _opening = false;
    }
  }

  Future<void> _releaseCamera() async {
    final cam = _camera;
    _camera = null;
    if (cam == null) return;
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } on CameraException {
      // dilepas juga di bawah
    }
    await cam.dispose();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_detecting || _phase != _Phase.scanning) return;
    _detecting = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _phase != _Phase.scanning) return;

      final face = faces.isEmpty
          ? null
          : faces.reduce(
              (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b,
            );
      if ((face != null) != _faceSeen) setState(() => _faceSeen = face != null);

      // Kedipan hanya dihitung bila lokasi sudah memenuhi syarat, supaya foto
      // tidak pernah diambil lalu ditolak karena lokasi.
      if (!_pre.ready) {
        if (_step != LivenessStep.noFace || _liveness.blinks > 0) {
          _liveness.reset();
          setState(() => _step = LivenessStep.noFace);
        }
        return;
      }

      final shortSide = math.min(image.width, image.height).toDouble();
      final step = _liveness.update(
        hasFace: face != null,
        yaw: face?.headEulerAngleY,
        roll: face?.headEulerAngleZ,
        leftEyeOpen: face?.leftEyeOpenProbability,
        rightEyeOpen: face?.rightEyeOpenProbability,
        faceWidthRatio: face == null ? 0 : face.boundingBox.width / shortSide,
      );

      if (step != _step || step == LivenessStep.blink) {
        if (step == LivenessStep.blink && _step != LivenessStep.blink) {
          HapticFeedback.selectionClick();
        }
        setState(() => _step = step);
      }
      if (step == LivenessStep.blink) {
        unawaited(_voice?.once('blink', 'Kedipkan mata anda'));
      }
      if (step == LivenessStep.noFace) _voice?.reset('blink');
      if (step == LivenessStep.done) await _captureAndSend();
    } catch (e) {
      debugPrint('[absen] deteksi wajah gagal: $e');
    } finally {
      _detecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final desc = _cameraDesc;
    if (desc == null || image.planes.isEmpty) return null;
    final rotation =
        InputImageRotationValue.fromRawValue(desc.sensorOrientation) ??
        InputImageRotation.rotation270deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21)) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _captureAndSend() async {
    final cam = _camera;
    final pos = _pre.position;
    if (cam == null || _phase != _Phase.scanning) return;
    if (!_pre.ready || pos == null) {
      _liveness.reset();
      setState(() => _step = LivenessStep.noFace);
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
      final shot = await cam.takePicture();
      if (!mounted) return;
      setState(() => _capture = File(shot.path));
      final repo = ref.read(attendanceRepositoryProvider);
      final msg = widget.early
          ? await repo.earlyCheckout(
              latitude: pos.latitude,
              longitude: pos.longitude,
              photo: File(shot.path),
              reason: widget.reason ?? '',
            )
          : await repo.submit(
              checkOut: widget.config.isCheckOut,
              latitude: pos.latitude,
              longitude: pos.longitude,
              locationId: _pre.nearest?.inRange == true
                  ? _pre.nearest!.id
                  : null,
              photo: File(shot.path),
            );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = _Phase.success;
        _resultMessage = msg;
      });
      await _voice?.say('Terima kasih');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) Navigator.of(context).pop(msg);
    } on ApiException catch (e) {
      _fail(e.message);
    } on CameraException catch (e) {
      _fail('Foto gagal diambil (${e.code}). Coba lagi.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  Future<void> _retry() async {
    _liveness.reset();
    _voice?.reset('blink');
    setState(() {
      _step = LivenessStep.noFace;
      _error = null;
      _capture = null;
    });
    final cam = _camera;
    if (cam == null) {
      setState(() => _phase = _Phase.waitCamera);
      await _openCamera();
      return;
    }
    setState(() => _phase = _Phase.scanning);
    if (!cam.value.isStreamingImages) await cam.startImageStream(_onFrame);
  }

  // ---------------- Aksi pemeriksaan ----------------

  Future<void> _onCheckAction(CheckId id) async {
    switch (id) {
      case CheckId.camera:
        if (_pre.camera?.isPermanentlyDenied == true) {
          await openAppSettings();
        } else {
          await _pre.requestCamera();
        }
      case CheckId.location:
        if (_pre.location == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        } else {
          await _pre.requestLocation();
        }
      case CheckId.gps:
        await _pre.openGpsSettings();
      case CheckId.points:
        await _pre.retryPoints();
      case CheckId.radius:
        await openNavigation(context, _pre.nearest);
      case CheckId.position:
      case CheckId.map:
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Bukan `inactive`: itu juga terpicu oleh dialog izin.
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _paused = true;
        // Android mencabut kamera di latar; lepas dengan rapi kecuali foto
        // sedang dikirim.
        if (_phase == _Phase.scanning || _phase == _Phase.starting) {
          unawaited(_releaseCamera());
          _liveness.reset();
          if (mounted) {
            setState(() {
              _phase = _Phase.waitCamera;
              _step = LivenessStep.noFace;
            });
          }
        }
      case AppLifecycleState.resumed:
        _paused = false;
        // Kembali dari pengaturan izin / GPS / aplikasi peta.
        unawaited(_pre.recheck());
        _maybeOpenCamera();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pre.removeListener(_onPreflight);
    _pre.dispose();
    unawaited(_releaseCamera());
    _detector.close();
    _voice?.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final diameter = math.min(size.width - 150, 240.0);
    final circleTop = mq.padding.top + 72;
    final statusTop = circleTop + diameter + Sp.lg;
    const statusHeight = 100.0;
    // Panel bawah awalnya hanya baris lokasi (+ alasan), supaya ada pita peta
    // yang lega antara kartu status dan panel.
    final sheetPeek =
        (widget.early ? 196.0 : 128.0) + mq.padding.bottom + Sp.md;
    final sheetMin = (sheetPeek / size.height).clamp(0.12, 0.4);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: _phase != _Phase.sending,
        child: Scaffold(
          backgroundColor: c.canvas,
          body: Stack(
            children: [
              Positioned.fill(
                child: AttendanceMap(
                  key: _mapKey,
                  pre: _pre,
                  fitPadding: EdgeInsets.fromLTRB(
                    56,
                    statusTop + statusHeight + Sp.lg,
                    56,
                    size.height * sheetMin + Sp.lg,
                  ),
                ),
              ),
              // Kabut lembut di bagian atas supaya kamera & teks terbaca di
              // atas peta; bagian tengah tetap jernih untuk posisi.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: statusTop + statusHeight + Sp.xl,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.canvas.withValues(alpha: 0.72),
                          c.canvas.withValues(alpha: 0.45),
                          c.canvas.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.6, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: mq.padding.top + Sp.sm,
                left: Sp.md,
                right: Sp.md,
                child: _TopBar(
                  title: _title,
                  subtitle: widget.config.shift?.name,
                  canClose: _phase != _Phase.sending,
                  face: _phase == _Phase.scanning ? _faceSeen : null,
                ),
              ),
              Positioned(
                top: circleTop,
                left: 0,
                right: 0,
                child: Center(
                  child: _FaceCircle(
                    diameter: diameter,
                    camera: _camera,
                    phase: _phase,
                    progress: _progress,
                    waiting: _phase == _Phase.scanning && !_pre.ready,
                    capture: _capture,
                  ),
                ),
              ),
              Positioned(
                top: statusTop,
                left: Sp.gutter,
                right: Sp.gutter,
                child: _StatusCard(
                  height: statusHeight,
                  status: _status(),
                  steps: _steps,
                  onRetry: switch (_phase) {
                    _Phase.failed => _retry,
                    _Phase.cameraBlocked => () {
                      setState(() => _phase = _Phase.waitCamera);
                      _openCamera();
                    },
                    _ => null,
                  },
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: sheetMin,
                minChildSize: sheetMin,
                maxChildSize: 0.8,
                snap: true,
                builder: (context, scroll) => _Sheet(
                  scroll: scroll,
                  pre: _pre,
                  early: widget.early,
                  reason: widget.reason,
                  onRecenter: () => _mapKey.currentState?.recenter(),
                  onAction: _onCheckAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kemajuan cincin kamera: wajah -> kedip 1 -> kedip 2 -> terkirim.
  double get _progress => switch (_phase) {
    _Phase.success => 1,
    _Phase.sending => 0.92,
    _Phase.scanning when _pre.ready => switch (_step) {
      LivenessStep.noFace => 0,
      LivenessStep.tilted || LivenessStep.tooFar => 0.12,
      LivenessStep.blink => 0.3 + 0.3 * math.min(_liveness.blinks, 2),
      LivenessStep.done => 0.92,
    },
    _ => 0,
  };

  ({bool face, int blinks, bool sent}) get _steps => (
    face:
        _phase.index >= _Phase.sending.index &&
            _phase != _Phase.cameraBlocked ||
        _step == LivenessStep.blink ||
        _step == LivenessStep.done,
    blinks: _phase == _Phase.success || _phase == _Phase.sending
        ? 2
        : math.min(_liveness.blinks, 2),
    sent: _phase == _Phase.success,
  );

  _Status _status() {
    switch (_phase) {
      case _Phase.waitCamera:
        final denied = _pre.camera != null && _pre.camera?.isGranted != true;
        return _Status(
          denied ? Icons.no_photography_outlined : Icons.camera_front_outlined,
          denied ? 'Izinkan kamera' : 'Menyiapkan kamera…',
          denied
              ? 'Kamera depan dipakai untuk foto wajah. Ketuk "Izinkan" di panel bawah.'
              : 'Sebentar, kamera depan sedang disiapkan.',
          denied ? _Tone.alert : _Tone.busy,
        );
      case _Phase.starting:
        return const _Status(
          Icons.camera_front_outlined,
          'Membuka kamera…',
          'Sebentar, kamera depan sedang disiapkan.',
          _Tone.busy,
        );
      case _Phase.cameraBlocked:
        return _Status(
          Icons.no_photography_outlined,
          'Kamera tidak tersedia',
          _error ?? 'Kamera tidak bisa dibuka.',
          _Tone.alert,
        );
      case _Phase.sending:
        return const _Status(
          Icons.cloud_upload_outlined,
          'Mengirim absen…',
          'Foto & lokasi sedang dikirim. Jangan tutup layar ini.',
          _Tone.busy,
        );
      case _Phase.success:
        return _Status(
          Icons.check_circle_rounded,
          'Absen tercatat',
          _resultMessage ?? 'Terima kasih.',
          _Tone.ok,
        );
      case _Phase.failed:
        return _Status(
          Icons.error_outline_rounded,
          'Absen belum tercatat',
          _error ?? 'Coba lagi.',
          _Tone.alert,
        );
      case _Phase.scanning:
        if (!_pre.ready) {
          final block = _pre
              .items()
              .where((i) => i.state == CheckState.fail)
              .firstOrNull;
          return block == null
              ? const _Status(
                  Icons.location_searching_rounded,
                  'Memeriksa lokasi…',
                  'Kedipan dihitung setelah lokasi siap.',
                  _Tone.busy,
                )
              : _Status(
                  Icons.wrong_location_outlined,
                  block.title,
                  block.detail,
                  _Tone.alert,
                );
        }
        return switch (_step) {
          LivenessStep.noFace => const _Status(
            Icons.face_outlined,
            'Hadapkan wajah ke kamera',
            'Posisikan wajah di dalam lingkaran.',
            _Tone.neutral,
          ),
          LivenessStep.tilted => const _Status(
            Icons.face_outlined,
            'Tegakkan kepala',
            'Lihat lurus ke kamera.',
            _Tone.neutral,
          ),
          LivenessStep.tooFar => const _Status(
            Icons.zoom_in_rounded,
            'Dekatkan wajah',
            'Wajah harus mengisi sebagian besar lingkaran.',
            _Tone.neutral,
          ),
          LivenessStep.blink => _Status(
            Icons.visibility_outlined,
            'Kedipkan mata dua kali',
            'Foto diambil otomatis setelah kedipan kedua (${math.min(_liveness.blinks, 2)}/2).',
            _Tone.ok,
          ),
          LivenessStep.done => const _Status(
            Icons.photo_camera_outlined,
            'Mengambil foto…',
            'Tahan posisi sebentar.',
            _Tone.ok,
          ),
        };
    }
  }
}

enum _Tone { neutral, busy, ok, alert }

class _Status {
  const _Status(this.icon, this.title, this.detail, this.tone);
  final IconData icon;
  final String title;
  final String detail;
  final _Tone tone;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.canClose,
    required this.face,
  });

  final String title;
  final String? subtitle;
  final bool canClose;

  /// Null = kamera belum memindai.
  final bool? face;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Row(
      children: [
        Material(
          color: c.surface,
          shape: const CircleBorder(),
          elevation: 0,
          child: IconButton(
            onPressed: canClose ? () => Navigator.of(context).pop() : null,
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Sp.sm),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.standard),
          child: face == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(face),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: face! ? c.primaryContainer : c.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        face! ? Icons.face_rounded : Icons.face_retouching_off,
                        size: 16,
                        color: face! ? c.primary : c.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        face! ? 'Wajah terdeteksi' : 'Mencari wajah',
                        style: context.text.labelSmall?.copyWith(
                          color: face! ? c.primary : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Kamera bundar dengan cincin kemajuan.
class _FaceCircle extends StatelessWidget {
  const _FaceCircle({
    required this.diameter,
    required this.camera,
    required this.phase,
    required this.progress,
    required this.waiting,
    this.capture,
  });

  final double diameter;
  final CameraController? camera;
  final _Phase phase;
  final double progress;

  /// Kamera aktif tetapi lokasi belum siap: pratinjau diredupkan.
  final bool waiting;
  final File? capture;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    const ring = 6.0;
    final inner = diameter - ring * 2 - 8;

    Widget content;
    final cam = camera;
    if (capture != null) {
      content = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: Image.file(capture!, fit: BoxFit.cover),
      );
    } else if (cam != null &&
        cam.value.isInitialized &&
        phase != _Phase.cameraBlocked) {
      // Rasio pratinjau mengikuti CameraPreview (1/aspectRatio saat potret),
      // lalu dipotong memenuhi lingkaran.
      final ratio = cam.value.aspectRatio;
      content = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 300,
          height: 300 * ratio,
          child: CameraPreview(cam),
        ),
      );
    } else {
      content = ColoredBox(
        color: c.heroBottom,
        child: Center(
          child: phase == _Phase.cameraBlocked || phase == _Phase.waitCamera
              ? Icon(
                  Icons.camera_front_outlined,
                  color: c.onHeroMuted,
                  size: 44,
                )
              : SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: c.onHero,
                  ),
                ),
        ),
      );
    }

    final ringColor = phase == _Phase.failed ? c.alert : c.primaryBright;

    return Semantics(
      label: 'Pratinjau kamera depan',
      child: SizedBox.square(
        dimension: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Alas putih + bayangan lembut memisahkan lingkaran dari peta.
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: phase == _Phase.failed ? 1 : progress),
              duration: Motion.of(context, Motion.emphasis),
              curve: Motion.curve,
              builder: (context, t, _) => CustomPaint(
                size: Size.square(diameter),
                painter: _RingPainter(
                  progress: t,
                  track: c.line,
                  color: ringColor,
                  width: ring,
                ),
              ),
            ),
            ClipOval(
              child: SizedBox.square(
                dimension: inner,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content,
                    AnimatedOpacity(
                      opacity: waiting || phase == _Phase.sending ? 1 : 0,
                      duration: Motion.of(context, Motion.standard),
                      child: const ColoredBox(color: Color(0x66000000)),
                    ),
                    if (phase == _Phase.sending)
                      const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (phase == _Phase.success)
                      const Center(child: _SuccessMark()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.width,
  });

  final double progress;
  final Color track;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2 + 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Satu-satunya animasi yang "dirayakan" (DESIGN.md §7): lingkaran jadi centang.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.emphasis),
      curve: Curves.easeOutBack,
      builder: (context, t, _) => Transform.scale(
        scale: 0.6 + 0.4 * t,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: c.primaryBright,
            shape: BoxShape.circle,
          ),
          child: CustomPaint(painter: _CheckPainter(progress: t)),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0, 1)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Kartu petunjuk di bawah kamera: satu kalimat aksi + rincian + langkah.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.height,
    required this.status,
    required this.steps,
    this.onRetry,
  });

  final double height;
  final _Status status;
  final ({bool face, int blinks, bool sent}) steps;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (fg, bg) = switch (status.tone) {
      _Tone.ok => (c.primary, c.primaryContainer),
      _Tone.alert => (c.alert, c.alertContainer),
      _Tone.busy || _Tone.neutral => (c.inkMuted, c.canvas),
    };
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.standard),
                  child: IconBadge(
                    status.icon,
                    key: ValueKey(status.icon),
                    size: 40,
                    iconSize: 22,
                    background: bg,
                    color: fg,
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: status.tone == _Tone.alert
                                ? c.alert
                                : c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: Sp.sm),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              _StepDot(label: 'Wajah', done: steps.face),
              _StepLine(done: steps.face),
              _StepDot(
                label: 'Kedip ${steps.blinks}/2',
                done: steps.blinks >= 2,
              ),
              _StepLine(done: steps.blinks >= 2),
              _StepDot(label: 'Terkirim', done: steps.sent),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.of(context, Motion.standard),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: done ? c.primaryBright : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? c.primaryBright : c.line,
              width: 2,
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: done ? c.primary : c.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AnimatedContainer(
      duration: Motion.of(context, Motion.standard),
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: done ? context.mx.primaryBright : context.mx.line,
    ),
  );
}

/// Panel bawah: titik terdekat + jarak realtime + arah/navigasi, alasan
/// (pulang lebih awal), lalu daftar pemeriksaan.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.scroll,
    required this.pre,
    required this.early,
    required this.reason,
    required this.onRecenter,
    required this.onAction,
  });

  final ScrollController scroll;
  final AttendancePreflight pre;
  final bool early;
  final String? reason;
  final VoidCallback onRecenter;
  final ValueChanged<CheckId> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final items = pre.items();
    final done = items
        .where((i) => i.state == CheckState.ok || i.state == CheckState.warn)
        .length;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.hero),
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          Sp.gutter,
          0,
          Sp.gutter,
          Sp.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: Sp.md),
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _LocationRow(pre: pre, early: early, onRecenter: onRecenter),
          if (early && reason != null) ...[
            const SizedBox(height: Sp.md),
            Container(
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: c.pendingContainer,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 20, color: c.pending),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      'Alasan: $reason',
                      style: context.text.bodyMedium?.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Sp.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pemeriksaan kesiapan',
                  style: context.text.titleSmall,
                ),
              ),
              Text(
                '$done/${items.length} siap',
                style: context.text.labelMedium?.copyWith(
                  color: done == items.length ? c.primary : c.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.xs),
          PreflightChecklist(items: items, onAction: onAction),
          const SizedBox(height: Sp.sm),
          Text(
            'Peta © kontributor OpenStreetMap',
            style: context.text.labelSmall?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.pre,
    required this.early,
    required this.onRecenter,
  });

  final AttendancePreflight pre;
  final bool early;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final p = pre.position;
    final n = pre.nearest;
    final free = early || pre.locationFree;

    late final Widget badge;
    late final String title;
    late final String detail;
    Widget? action;

    if (p == null) {
      badge = SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.primary),
        ),
      );
      title = 'Mencari posisi Anda…';
      detail = 'Pastikan GPS aktif. Di dalam gedung bisa lebih lama.';
    } else if (free) {
      badge = const IconBadge(Icons.where_to_vote_rounded, size: 44);
      title = n == null ? 'Lokasi dicatat' : 'Dekat ${n.name}';
      detail =
          '${n == null ? '' : '${meters(n.distance ?? 0)} dari titik · '}akurasi ±${p.accuracy.round()} m';
    } else if (n == null) {
      badge = SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.primary),
        ),
      );
      title = 'Mencari titik absen terdekat…';
      detail = 'Akurasi ±${p.accuracy.round()} m';
    } else if (n.inRange) {
      badge = const IconBadge(Icons.where_to_vote_rounded, size: 44);
      title = n.name;
      detail =
          '${meters(n.distance ?? 0)} dari titik · di dalam radius ${n.radiusMeters} m';
    } else {
      final dir = pre.directionToNearest();
      badge = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.alertContainer,
          shape: BoxShape.circle,
        ),
        // Panah penunjuk arah ke titik terdekat (utara = atas, sama seperti peta).
        child: AnimatedRotation(
          turns: (pre.bearingToNearest() ?? 0) / 360,
          duration: Motion.of(context, Motion.standard),
          child: Icon(
            Icons.navigation_rounded,
            color: c.alert,
            semanticLabel: 'Arah ${dir ?? ''}',
          ),
        ),
      );
      title = 'Menuju ${n.name}';
      detail =
          '${meters(n.distance ?? 0)}${dir == null ? '' : ' ke arah $dir'} · masuk radius ${n.radiusMeters} m';
      action = FilledButton(
        onPressed: () => openNavigation(context, n),
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Text('Navigasi'),
      );
    }

    return Row(
      children: [
        badge,
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              Text(
                detail,
                style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: Sp.sm), action],
        if (p != null)
          IconButton(
            onPressed: onRecenter,
            tooltip: 'Pusatkan peta',
            icon: Icon(Icons.my_location_rounded, color: c.primary),
          ),
      ],
    );
  }
}
