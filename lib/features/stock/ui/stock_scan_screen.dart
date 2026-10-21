import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/sound/scan_sound.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/widgets/mx.dart';
import '../data/stock_repository.dart';
import 'scan_brackets.dart';
import 'stock_history_screen.dart';
import 'stock_take_sheet.dart';

/// Scan QR label barang/reagen SENTRA. Mode biasa: scan -> periksa -> ambil.
/// Scan Cepat: scan -> langsung berkurang 1 unit dengan catatan "Scan Cepat".
class StockScanScreen extends ConsumerStatefulWidget {
  const StockScanScreen({
    super.key,
    this.debugScanner,
    this.debugBeep,
    this.debugNow,
  });

  /// Pengganti kamera di tes: menerima callback deteksi.
  @visibleForTesting
  final Widget Function(void Function(BarcodeCapture) onDetect)? debugScanner;
  @visibleForTesting
  final VoidCallback? debugBeep;
  @visibleForTesting
  final DateTime Function()? debugNow;

  @override
  ConsumerState<StockScanScreen> createState() => _StockScanScreenState();
}

class _StockScanScreenState extends ConsumerState<StockScanScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController? _camera = widget.debugScanner != null
      ? null
      : MobileScannerController(
          formats: const [BarcodeFormat.qrCode],
          detectionSpeed: DetectionSpeed.normal,
          detectionTimeoutMs: 120,
        );
  late final ScanSound? _sound = widget.debugBeep != null ? null : ScanSound();

  DateTime _now() => (widget.debugNow ?? DateTime.now)();

  /// QR yang sama baru dihitung lagi setelah keluar dari bingkai selama ini.
  static const _rearm = Duration(milliseconds: 700);
  static const _lost = Duration(milliseconds: 500);

  late final Ticker _ticker;
  Size _screen = Size.zero;
  Quad? _current;
  Quad? _target;
  bool _locked = false;
  Timer? _lostTimer;

  bool _quick = false;
  bool _busy = false; // sedang memproses satu QR; deteksi lain diabaikan
  bool _loading = false; // menunggu server
  String? _armedOff; // kode terakhir yang diproses; menunggu keluar bingkai
  DateTime _lastSeen = DateTime.fromMillisecondsSinceEpoch(0);

  final List<StockTakeResult> _session = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    ref.read(secureStoreProvider).quickScan().then((v) {
      if (mounted) setState(() => _quick = v);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _lostTimer?.cancel();
    _camera?.dispose();
    _sound?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ bingkai

  void _tick(Duration _) {
    final target = _target;
    if (target == null || _current == null) return _ticker.stop();
    final next = lerpQuad(_current!, target, 0.28);
    final settled = [
      for (var i = 0; i < 4; i++) (next[i] - target[i]).distance,
    ].every((d) => d < 0.5);
    setState(() => _current = settled ? target : next);
    if (settled) _ticker.stop();
  }

  void _moveTo(Quad quad) {
    _target = quad;
    _current ??= quad;
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
      setState(() => _current = quad);
      return;
    }
    if (!_ticker.isActive) _ticker.start();
  }

  void _release() {
    _locked = false;
    if (_screen != Size.zero) _moveTo(idleQuad(_screen));
    setState(() {});
  }

  // ------------------------------------------------------------ deteksi

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes
        .where((b) => (b.rawValue ?? '').isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    final value = code.rawValue!;
    final now = _now();
    final continuous = now.difference(_lastSeen) < _rearm;
    _lastSeen = now;

    final quad = quadOnScreen(code, capture.size, _screen);
    if (quad != null) _moveTo(quad);
    _lostTimer?.cancel();
    _lostTimer = Timer(_lost, _release);

    if (_busy) return;
    // QR yang sama dan belum keluar bingkai: jangan dihitung dua kali.
    if (value == _armedOff && continuous) return;
    _armedOff = value;

    if (!_locked) {
      _locked = true;
      HapticFeedback.mediumImpact();
      widget.debugBeep != null ? widget.debugBeep!() : _sound?.beep();
    }
    _quick ? _quickTake(value) : _review(value);
  }

  Future<void> _quickTake(String value) async {
    setState(() {
      _busy = _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(stockRepositoryProvider)
          .take(value, quick: true);
      if (!mounted) return;
      setState(() => _session.insert(0, res));
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = _loading = false);
    }
  }

  Future<void> _review(String value) async {
    setState(() {
      _busy = _loading = true;
      _error = null;
    });
    try {
      final batch = await ref.read(stockRepositoryProvider).verify(value);
      if (!mounted) return;
      setState(() => _loading = false);
      final res = await showStockTakeSheet(context, code: value, batch: batch);
      if (res != null && mounted) {
        setState(() => _session.insert(0, res));
        showMxSnack(
          context,
          '${res.quantity} ${res.batch.unitLabel} ${res.batch.itemName} tercatat.',
          tone: Tone.ok,
        );
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = '$e');
    } finally {
      // Lembar ditutup: QR yang masih di bingkai harus diarahkan ulang dulu.
      _lastSeen = _now();
      if (mounted) setState(() => _busy = _loading = false);
    }
  }

  Future<void> _undo(StockTakeResult r) async {
    try {
      await ref.read(stockRepositoryProvider).undo(r.transactionId);
      if (!mounted) return;
      setState(() => _session.remove(r));
      showMxSnack(context, 'Pengambilan dibatalkan, stok dikembalikan.');
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    }
  }

  Future<void> _setQuick(bool v) async {
    setState(() => _quick = v);
    await ref.read(secureStoreProvider).setQuickScan(v);
  }

  // ------------------------------------------------------------ tampilan

  @override
  Widget build(BuildContext context) {
    // Hijau terang terbaca di atas video kamera yang gelap maupun terang.
    const locked = Color(0xFF34D399);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, box) {
            if (_screen != box.biggest) {
              _screen = box.biggest;
              final idle = idleQuad(_screen);
              _current = _locked ? _current : idle;
              _target = _locked ? _target : idle;
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                if (widget.debugScanner != null)
                  widget.debugScanner!(_onDetect)
                else
                  MobileScanner(
                    controller: _camera,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) =>
                        _CameraError(error: error),
                  ),
                if (_current != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: ScanBracketsPainter(
                        quad: _current!,
                        color: _locked ? locked : Colors.white,
                        strokeWidth: _locked ? 5 : 4,
                      ),
                    ),
                  ),
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(camera: _camera),
                      _QuickToggle(value: _quick, onChanged: _setQuick),
                      const Spacer(),
                      _BottomPanel(
                        quick: _quick,
                        busy: _loading,
                        error: _error,
                        session: _session,
                        onUndo: _undo,
                        onDismissError: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.camera});
  final MobileScannerController? camera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xs, Sp.xs, 0),
      child: Row(
        children: [
          _RoundIcon(
            icon: Icons.arrow_back_rounded,
            label: 'Kembali',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: Sp.xs),
          Expanded(
            child: Text(
              'Scan barang',
              style: context.text.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (camera case final cam?)
            ValueListenableBuilder(
              valueListenable: cam,
              builder: (context, state, _) {
                final on = state.torchState == TorchState.on;
                if (state.torchState == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                return _RoundIcon(
                  icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  label: on ? 'Matikan senter' : 'Nyalakan senter',
                  onTap: cam.toggleTorch,
                );
              },
            ),
          const SizedBox(width: Sp.xs),
          _RoundIcon(
            icon: Icons.history_rounded,
            label: 'Riwayat ambil barang',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StockHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    ),
  );
}

class _QuickToggle extends StatelessWidget {
  const _QuickToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  static const _help =
      'Saat aktif, setiap QR yang terbaca langsung mengurangi stok 1 unit '
      'dengan catatan "Scan Cepat", tanpa layar konfirmasi. Cocok untuk '
      'mengambil banyak barang. Untuk mengambil 1 lagi dari barang yang sama, '
      'jauhkan kamera lalu arahkan kembali. Salah scan bisa dibatalkan dalam '
      '10 menit.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Sp.sm),
      child: Container(
        padding: const EdgeInsets.only(left: Sp.lg, right: Sp.xs),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan Cepat',
              style: context.text.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Tooltip(
              message: _help,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 10),
              margin: const EdgeInsets.symmetric(horizontal: Sp.gutter),
              padding: const EdgeInsets.all(Sp.md),
              textStyle: context.text.bodySmall?.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
              child: Semantics(
                button: true,
                label: 'Tentang Scan Cepat',
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Scan Cepat',
              toggled: value,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.quick,
    required this.busy,
    required this.error,
    required this.session,
    required this.onUndo,
    required this.onDismissError,
  });

  final bool quick;
  final bool busy;
  final String? error;
  final List<StockTakeResult> session;
  final ValueChanged<StockTakeResult> onUndo;
  final VoidCallback onDismissError;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final last = session.firstOrNull;
    final total = session.fold<int>(0, (a, r) => a + r.quantity);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(Sp.md),
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_rounded, color: c.alert, size: 20),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    error!,
                    style: context.text.bodyMedium?.copyWith(color: c.alert),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup pesan',
                  onPressed: onDismissError,
                  icon: Icon(Icons.close_rounded, color: c.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: Sp.sm),
          ],
          if (last == null)
            Text(
              busy
                  ? 'Membaca label…'
                  : quick
                  ? 'Arahkan kamera ke QR pada label barang. Setiap QR yang terbaca langsung mengurangi stok 1 unit.'
                  : 'Arahkan kamera ke QR pada label barang. Setelah terbaca, periksa jumlah lalu ambil.',
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Diambil di sesi ini: $total unit',
                    style: context.text.labelLarge?.copyWith(color: c.inkMuted),
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            _LastTake(result: last, onUndo: () => onUndo(last)),
            if (quick) ...[
              const SizedBox(height: Sp.sm),
              Text(
                'Untuk 1 lagi dari barang yang sama, jauhkan kamera lalu arahkan kembali.',
                style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LastTake extends StatelessWidget {
  const _LastTake({required this.result, required this.onUndo});
  final StockTakeResult result;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final b = result.batch;
    final undoable =
        result.undoUntil != null && result.undoUntil!.isAfter(DateTime.now());
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: c.primary),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '−${result.quantity} ${b.unitLabel} · sisa ${Fmt.number(b.remaining)} ${b.unitLabel}',
                style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        if (undoable)
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Batalkan'),
          ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: Sp.md),
              Text(
                denied ? 'Izin kamera ditolak' : 'Kamera tidak bisa dibuka',
                style: context.text.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: Sp.xs),
              Text(
                denied
                    ? 'MATRIX perlu kamera untuk membaca QR label barang. Izinkan kamera di pengaturan HP.'
                    : 'Tutup aplikasi kamera lain lalu buka layar ini lagi.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: Colors.white70),
              ),
              if (denied) ...[
                const SizedBox(height: Sp.lg),
                const FilledButton(
                  onPressed: openAppSettings,
                  child: Text('Buka pengaturan'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
