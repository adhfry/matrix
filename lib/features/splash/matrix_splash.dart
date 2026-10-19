import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/sound/brand_sound.dart';
import '../../core/storage/secure_store.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/matrix_mark.dart';

/// Sudah lewat splash di proses aplikasi ini (sekali per buka aplikasi).
class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashDone, bool>(SplashDone.new);

/// Splash beranimasi, disinkronkan dengan suara pembuka "Ma-triks": pita
/// hijau M tergores dan "Ma" terucap di ujungnya, pita emas-merah tergores
/// bersama "triks" (nada naik), logo memantul + getar halus, lalu wordmark
/// naik. Total +-2,9 detik; dengan "kurangi animasi" logo langsung penuh.
class MatrixSplash extends ConsumerStatefulWidget {
  const MatrixSplash({super.key});

  @override
  ConsumerState<MatrixSplash> createState() => _MatrixSplashState();
}

class _MatrixSplashState extends ConsumerState<MatrixSplash>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2900);

  /// Suara dimulai di sini supaya "Maa" (0-0,36 dtk di berkas) selesai di
  /// ujung goresan hijau dan "triks" (0,38-0,85 dtk) jatuh di goresan merah.
  static const _voiceAtSeconds = 0.48;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _spoke = false;
  bool _landed = false;

  // Bagian timeline (0..1 terhadap _total).
  static final _markEnd =
      MatrixMark.totalSeconds * 1000 / _total.inMilliseconds;
  static final _landAt =
      MatrixMark.landingSeconds * 1000 / _total.inMilliseconds;
  static final _voiceAt = _voiceAtSeconds * 1000 / _total.inMilliseconds;

  double _at(double seconds) => seconds * 1000 / _total.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    // Saat transisi keluar, pengalih layar bisa membuat ulang widget ini:
    // tampilkan logo penuh tanpa mengulang animasi & bunyi.
    if (ref.read(splashDoneProvider)) {
      _spoke = _landed = true;
      _c.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _speak();
        _land();
        _c.value = 1;
        Future<void>.delayed(const Duration(milliseconds: 1200), _finish);
      } else {
        _c.forward().whenComplete(_finish);
      }
    });
  }

  void _onTick() {
    if (!_spoke && _c.value >= _voiceAt) _speak();
    if (!_landed && _c.value >= _landAt) _land();
  }

  void _speak() {
    _spoke = true;
    BrandSound.intro(ref.read(secureStoreProvider));
  }

  void _land() {
    _landed = true;
    HapticFeedback.lightImpact();
  }

  void _finish() {
    if (mounted) ref.read(splashDoneProvider.notifier).finish();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Scaffold(
      backgroundColor: c.canvas,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final mark = (v / _markEnd).clamp(0.0, 1.0);
          double phase(double a, double b) => Curves.easeOutCubic.transform(
            ((v - a) / (b - a)).clamp(0.0, 1.0),
          );
          final word = phase(_at(1.70), _at(2.20));
          final sub = phase(_at(1.95), _at(2.45));
          return Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MatrixMark(size: 112, progress: mark),
                    const SizedBox(height: Sp.xl),
                    Opacity(
                      opacity: word,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - word)),
                        child: MatrixWordmark(color: c.ink, size: 30),
                      ),
                    ),
                    const SizedBox(height: Sp.sm),
                    Opacity(
                      opacity: sub,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.xxl),
                        child: MatrixAcronym(
                          strong: c.ink,
                          soft: c.inkMuted,
                          style: context.text.bodySmall,
                          textAlign: TextAlign.center,
                          balanced: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + Sp.xl,
                child: Opacity(
                  opacity: sub,
                  child: Text(
                    'UPTD Labkesda Kabupaten Sumenep',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
