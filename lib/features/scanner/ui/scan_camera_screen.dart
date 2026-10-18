import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/tokens.dart';
import '../logic/ktp_image.dart';
import 'scan_review_screen.dart';

/// Kamera belakang dengan bingkai seukuran KTP. Foto dipotong ke bingkai.
class ScanCameraScreen extends StatefulWidget {
  const ScanCameraScreen({super.key});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cam;
  String? _error;
  bool _busy = false;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      await ctrl.setFlashMode(FlashMode.off);
      try {
        await ctrl.setFocusMode(FocusMode.auto);
      } on CameraException {
        // tidak semua kamera mendukung
      }
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _cam = ctrl);
    } on CameraException catch (e) {
      setState(
        () => _error = e.code.toLowerCase().contains('denied')
            ? 'Izin kamera ditolak.'
            : 'Kamera tidak bisa dibuka (${e.code}).',
      );
    }
  }

  Future<void> _shoot() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      final x = await cam.takePicture();
      final file = await prepareKtpPhoto(File(x.path));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ScanReviewScreen(photo: file)),
      );
    } on CameraException catch (e) {
      setState(() {
        _busy = false;
        _error = 'Foto gagal (${e.code}). Coba lagi.';
      });
    }
  }

  Future<void> _toggleFlash() async {
    final cam = _cam;
    if (cam == null) return;
    _flash = !_flash;
    await cam.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cam?.dispose();
      _cam = null;
    } else if (state == AppLifecycleState.resumed && _cam == null && mounted) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto KTP'),
        actions: [
          if (cam != null)
            IconButton(
              onPressed: _toggleFlash,
              tooltip: _flash ? 'Matikan lampu' : 'Nyalakan lampu',
              icon: Icon(
                _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Sp.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: context.text.bodyLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: Sp.lg),
                            const FilledButton(
                              onPressed: openAppSettings,
                              child: Text('Buka pengaturan izin'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : cam == null
                  ? Center(
                      child: Text(
                        'Membuka kamera…',
                        style: context.text.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        final ratio = cam.value.aspectRatio;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: 300,
                                    height: 300 * ratio,
                                    child: CameraPreview(cam),
                                  ),
                                ),
                              ),
                            ),
                            CustomPaint(painter: _CardFrame()),
                            Positioned(
                              left: Sp.xl,
                              right: Sp.xl,
                              bottom: Sp.lg,
                              child: Text(
                                'Letakkan KTP di dalam bingkai, di atas permukaan gelap, tanpa pantulan cahaya.',
                                textAlign: TextAlign.center,
                                style: context.text.bodyMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.xl),
              child: Semantics(
                button: true,
                label: 'Ambil foto KTP',
                child: GestureDetector(
                  onTap: _shoot,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bingkai rasio ID-1; luar bingkai digelapkan, sudut ditegaskan.
class _CardFrame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * ktpFrameWidthFactor;
    final h = w / ktpAspect;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w,
      height: h,
    );
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(rr),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CardFrame oldDelegate) => false;
}
