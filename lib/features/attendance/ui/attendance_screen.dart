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
import '../../../core/format/fmt.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';
import '../logic/liveness.dart';
import '../logic/preflight.dart';
import 'preflight_view.dart';
import 'voice_guide.dart';

enum _Phase {
  preflight,
  starting,
  scanning,
  sending,
  success,
  failed,
  cameraBlocked,
}

/// Absen wajah: pra-cek kesiapan -> kamera depan -> wajah tegak -> kedip 2x ->
/// foto otomatis -> kirim. [early] = pulang lebih awal (bebas radius, wajib alasan).
/// Mengembalikan pesan server lewat Navigator.pop.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.config, this.early = false});

  final AttendanceConfig config;
  final bool early;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with WidgetsBindingObserver {
  late final AttendancePreflight _pre;
  final _reason = TextEditingController();

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

  _Phase _phase = _Phase.preflight;
  LivenessStep _step = LivenessStep.noFace;
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
    _reason.addListener(() => setState(() {}));
    _pre.start();
    ref.read(secureStoreProvider).ttsEnabled().then((on) async {
      _voice = VoiceGuide(enabled: on);
      await _voice!.init();
    });
  }

  void _onPreflight() {
    if (!mounted) return;
    // Saat kamera berjalan, lokasi tetap dipantau: keluar radius = tunda foto.
    setState(() {});
  }

  bool get _reasonOk => !widget.early || _reason.text.trim().length >= 5;

  // ---------------- Kamera & wajah ----------------

  Future<void> _openCamera() async {
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    try {
      final cams = await availableCameras();
      _cameraDesc = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        _cameraDesc!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      _camera = ctrl;
      setState(() => _phase = _Phase.scanning);
      await ctrl.startImageStream(_onFrame);
      unawaited(
        _voice?.once(
          'welcome',
          'Halo ${widget.config.userName.split(' ').first}, hadapkan wajah anda ke kamera',
        ),
      );
    } on CameraException catch (e) {
      setState(() {
        _phase = _Phase.cameraBlocked;
        _error =
            'Kamera tidak bisa dibuka (${e.code}). Tutup aplikasi lain yang memakai kamera lalu coba lagi.';
      });
    }
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
    if (cam == null) return;
    if (!_pre.ready || pos == null) {
      _liveness.reset();
      HapticFeedback.heavyImpact();
      setState(() {
        _step = LivenessStep.noFace;
        _error = pos == null
            ? 'Lokasi belum ditemukan. Tunggu sebentar.'
            : 'Lokasi berubah dan tidak lagi memenuhi syarat. Periksa panel lokasi di bawah.';
      });
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    try {
      await cam.stopImageStream();
      final shot = await cam.takePicture();
      setState(() => _capture = File(shot.path));
      final repo = ref.read(attendanceRepositoryProvider);
      final msg = widget.early
          ? await repo.earlyCheckout(
              latitude: pos.latitude,
              longitude: pos.longitude,
              photo: File(shot.path),
              reason: _reason.text.trim(),
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
      await Future<void>.delayed(const Duration(milliseconds: 900));
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
      _phase = _Phase.scanning;
      _step = LivenessStep.noFace;
      _error = null;
      _capture = null;
    });
    final cam = _camera;
    if (cam != null && !cam.value.isStreamingImages) {
      await cam.startImageStream(_onFrame);
    }
  }

  // ---------------- Aksi pra-cek ----------------

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
    final cam = _camera;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (cam != null && cam.value.isStreamingImages) cam.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      // Kembali dari pengaturan izin / GPS / aplikasi peta.
      _pre.recheck();
      if (cam != null &&
          _phase == _Phase.scanning &&
          !cam.value.isStreamingImages) {
        cam.startImageStream(_onFrame);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pre.removeListener(_onPreflight);
    _pre.dispose();
    _reason.dispose();
    _camera?.dispose();
    _detector.close();
    _voice?.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final inPreflight = _phase == _Phase.preflight;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: CloseButton(
          onPressed: _phase == _Phase.sending
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: Motion.of(context, Motion.emphasis),
        child: inPreflight ? _buildPreflight(context) : _buildCamera(context),
      ),
    );
  }

  Widget _buildPreflight(BuildContext context) {
    final c = context.mx;
    final ready = _pre.ready && _reasonOk;
    final blocking = _pre
        .items()
        .where((i) => i.state == CheckState.fail)
        .firstOrNull;
    final early = widget.config.early;
    return Column(
      key: const ValueKey('pre'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.lg),
            children: [
              StaggerIn(
                index: 0,
                child: PreflightMap(
                  pre: _pre,
                  onNavigate: () => openNavigation(context, _pre.nearest),
                ),
              ),
              const SizedBox(height: Sp.lg),
              if (widget.early) ...[
                StaggerIn(
                  index: 1,
                  child: MxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconBadge(
                              Icons.directions_walk_rounded,
                              size: 40,
                              background: c.pendingContainer,
                              color: c.pending,
                            ),
                            const SizedBox(width: Sp.md),
                            Expanded(
                              child: Text(
                                'Check-out sebelum jendela check-out',
                                style: context.text.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Sp.md),
                        Text(
                          early.earlySeconds > 0
                              ? 'Jam kerja yang ditinggalkan sekitar ${Fmt.hmLong(early.earlySeconds)} (sampai ${early.workEnd == null ? 'jam pulang' : Fmt.timeOf(early.workEnd!)}). Waktu ini dihitung pulang cepat dan memotong jam kerja per detik.'
                              : 'Waktu yang ditinggalkan dihitung pulang cepat dan memotong jam kerja per detik.',
                          style: context.text.bodyMedium?.copyWith(
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: Sp.md),
                        TextField(
                          controller: _reason,
                          maxLength: 255,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Alasan pulang lebih awal *',
                            hintText:
                                'Contoh: anak sakit, dijemput dari sekolah',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Sp.lg),
              ],
              StaggerIn(
                index: 2,
                child: PreflightChecklist(
                  items: _pre.items(),
                  onAction: _onCheckAction,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.sm,
              Sp.gutter,
              Sp.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.standard),
                  child: ready
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(blocking?.id),
                          padding: const EdgeInsets.only(bottom: Sp.sm),
                          child: Text(
                            blocking != null
                                ? '${blocking.title}: ${blocking.detail}'
                                : (!_reasonOk
                                      ? 'Tulis alasan minimal 5 huruf.'
                                      : 'Menyiapkan pemeriksaan…'),
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall?.copyWith(
                              color: blocking != null ? c.alert : c.inkMuted,
                            ),
                          ),
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: ready ? _openCamera : null,
                    icon: const Icon(Icons.camera_front_rounded),
                    label: Text(
                      ready ? 'Lanjut ke foto wajah' : 'Menunggu semua siap',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCamera(BuildContext context) {
    final c = context.mx;
    final n = _pre.nearest;
    return ListView(
      key: const ValueKey('cam'),
      padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xl),
      children: [
        _CameraFrame(
          camera: _camera,
          phase: _phase,
          step: _step,
          capture: _capture,
          error: _phase == _Phase.cameraBlocked ? _error : null,
        ),
        const SizedBox(height: Sp.lg),
        _Instruction(
          phase: _phase,
          step: _step,
          blinks: _liveness.blinks,
          resultMessage: _resultMessage,
        ),
        if (_error != null && _phase != _Phase.cameraBlocked) ...[
          const SizedBox(height: Sp.md),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: c.alertContainer,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: c.alert, size: 20),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: context.text.bodyMedium?.copyWith(color: c.alert),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_phase == _Phase.failed) ...[
          const SizedBox(height: Sp.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
        if (_phase == _Phase.cameraBlocked) ...[
          const SizedBox(height: Sp.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openCamera,
              child: const Text('Buka kamera lagi'),
            ),
          ),
        ],
        const SizedBox(height: Sp.lg),
        MxCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.lg,
            vertical: Sp.md,
          ),
          child: Row(
            children: [
              IconBadge(
                _pre.ready
                    ? Icons.where_to_vote_outlined
                    : Icons.wrong_location_outlined,
                size: 36,
                background: _pre.ready ? c.primaryContainer : c.alertContainer,
                color: _pre.ready ? c.primary : c.alert,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  widget.early || widget.config.isLocationFree
                      ? 'Lokasi dicatat${_pre.position == null ? '' : ' (±${_pre.position!.accuracy.round()} m)'}'
                      : (n == null
                            ? 'Menunggu lokasi…'
                            : '${n.name}: ${(n.distance ?? 0).round()} m dari titik${n.inRange ? '' : ' (di luar radius)'}'),
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({
    required this.camera,
    required this.phase,
    required this.step,
    this.capture,
    this.error,
  });

  final CameraController? camera;
  final _Phase phase;
  final LivenessStep step;
  final File? capture;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final ringColor = switch (phase) {
      _Phase.success => c.primaryBright,
      _Phase.failed => c.alert,
      _ =>
        step == LivenessStep.blink || step == LivenessStep.done
            ? c.primaryBright
            : Colors.white70,
    };

    Widget content;
    if (error != null) {
      content = Container(
        color: c.ink,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, color: c.canvas, size: 40),
            const SizedBox(height: Sp.md),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.canvas),
            ),
          ],
        ),
      );
    } else if (capture != null) {
      content = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: Image.file(capture!, fit: BoxFit.cover),
      );
    } else if (camera != null && camera!.value.isInitialized) {
      // Ukuran kotak mengikuti rasio yang dipakai CameraPreview sendiri (1/aspectRatio
      // saat potret) supaya tidak ada bingkai hitam, lalu dipotong memenuhi bidang.
      final ratio = camera!.value.aspectRatio;
      content = ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 300,
              height: 300 * ratio,
              child: CameraPreview(camera!),
            ),
          ),
        ),
      );
    } else {
      content = Container(
        color: c.ink,
        alignment: Alignment.center,
        child: Text(
          'Membuka kamera…',
          style: context.text.bodyMedium?.copyWith(color: c.canvas),
        ),
      );
    }

    return Semantics(
      label: 'Pratinjau kamera depan',
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (error == null)
                CustomPaint(
                  painter: _OvalGuide(
                    ring: ringColor,
                    dim: phase == _Phase.success ? 0.55 : 0.35,
                  ),
                ),
              if (phase == _Phase.sending)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sp.lg,
                      vertical: Sp.md,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: Sp.md),
                        Text(
                          'Mengirim absen…',
                          style: context.text.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (phase == _Phase.success) const Center(child: _SuccessMark()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oval panduan posisi wajah; area di luar oval digelapkan.
class _OvalGuide extends CustomPainter {
  _OvalGuide({required this.ring, required this.dim});

  final Color ring;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * 0.66,
      height: size.height * 0.62,
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: dim),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_OvalGuide old) => old.ring != ring || old.dim != dim;
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
          width: 96,
          height: 96,
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

/// Langkah yang sedang berjalan + petunjuk satu kalimat.
class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.phase,
    required this.step,
    required this.blinks,
    this.resultMessage,
  });

  final _Phase phase;
  final LivenessStep step;
  final int blinks;
  final String? resultMessage;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final text = switch (phase) {
      _Phase.preflight || _Phase.starting => 'Menyiapkan kamera…',
      _Phase.cameraBlocked => 'Kamera tidak tersedia.',
      _Phase.sending => 'Foto diambil. Mengirim ke server…',
      _Phase.success => resultMessage ?? 'Absen tercatat.',
      _Phase.failed => 'Absen belum tercatat.',
      _Phase.scanning => switch (step) {
        LivenessStep.noFace => 'Posisikan wajah di dalam oval.',
        LivenessStep.tilted => 'Tegakkan kepala dan lihat lurus ke kamera.',
        LivenessStep.tooFar => 'Dekatkan wajah ke kamera.',
        LivenessStep.blink => 'Kedipkan mata dua kali ($blinks/2).',
        LivenessStep.done => 'Mengambil foto…',
      },
    };
    final faceOk =
        step == LivenessStep.blink ||
        step == LivenessStep.done ||
        phase.index >= _Phase.sending.index;
    final blinkOk =
        step == LivenessStep.done || phase.index >= _Phase.sending.index;
    final sent = phase == _Phase.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(text, style: context.text.titleMedium),
        ),
        const SizedBox(height: Sp.md),
        Row(
          children: [
            _StepChip(label: 'Wajah', done: faceOk),
            _StepLine(done: faceOk),
            _StepChip(label: 'Kedip ${math.min(blinks, 2)}/2', done: blinkOk),
            _StepLine(done: blinkOk),
            _StepChip(label: 'Terkirim', done: sent),
          ],
        ),
        if (phase == _Phase.scanning) ...[
          const SizedBox(height: Sp.sm),
          Text(
            'Foto diambil otomatis setelah kedipan kedua.',
            style: context.text.bodySmall?.copyWith(color: c.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.standard),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? c.primaryContainer : c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? c.primaryContainer : c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_rounded : Icons.circle_outlined,
            size: 14,
            color: done ? c.primary : c.inkMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: done ? c.primary : c.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: done ? context.mx.primaryBright : context.mx.line,
    ),
  );
}
