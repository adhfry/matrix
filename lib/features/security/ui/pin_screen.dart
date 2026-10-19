import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/matrix_mark.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/session.dart';
import '../pin_service.dart';

enum _PinMode { unlock, create, verify }

/// Satu layar untuk membuka kunci, membuat, dan memverifikasi PIN 6 digit.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen._(
    this._mode, {
    required this.user,
    this.biometric = false,
    this.hasPin = true,
  });

  /// Layar akar saat aplikasi terkunci. [hasPin] false = hanya biometrik.
  factory PinScreen.unlock({
    required AppUser user,
    required bool biometric,
    bool hasPin = true,
  }) => PinScreen._(
    _PinMode.unlock,
    user: user,
    biometric: biometric,
    hasPin: hasPin,
  );

  /// Dibuka dengan Navigator.push; mengembalikan `true` bila PIN tersimpan.
  factory PinScreen.create({required AppUser user}) =>
      PinScreen._(_PinMode.create, user: user);

  /// Konfirmasi PIN lama sebelum ubah/hapus; mengembalikan `true` bila cocok.
  factory PinScreen.verify({required AppUser user}) =>
      PinScreen._(_PinMode.verify, user: user);

  final _PinMode _mode;
  final AppUser user;
  final bool biometric;
  final bool hasPin;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  static const _len = 6;
  String _pin = '';
  String? _first; // langkah pertama saat membuat PIN
  String? _error;
  int _wrong = 0;
  bool _checking = false;
  bool _authing = false;

  /// "sidik jari" / "wajah" / "biometrik" sesuai sensor HP.
  String _bioName = 'sidik jari';

  PinService get _svc => ref.read(pinServiceProvider);

  @override
  void initState() {
    super.initState();
    if (widget._mode == _PinMode.unlock && widget.biometric) {
      _svc.biometricName().then((n) {
        if (mounted) setState(() => _bioName = n);
      });
      // Jeda singkat: dialog biometrik Android gagal muncul bila aplikasi
      // belum sepenuhnya di depan (baru dibuka / kembali dari latar).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Future<void>.delayed(
          const Duration(milliseconds: 350),
          _tryBiometric,
        ),
      );
    }
  }

  Future<void> _tryBiometric() async {
    if (_authing || _checking || !mounted) return;
    _authing = true;
    try {
      if (await _svc.authenticate()) {
        HapticFeedback.lightImpact();
        if (mounted) setState(() => _checking = true);
        await ref.read(sessionProvider.notifier).unlocked();
      }
    } finally {
      _authing = false;
    }
  }

  /// Setelah PIN dibuat: tawarkan biometrik sekaligus (satu alur, bukan
  /// dicari di menu Akun). Diaktifkan hanya setelah pindaian berhasil.
  Future<void> _offerBiometric() async {
    if (await _svc.biometricEnabled() ||
        !await _svc.biometricAvailable() ||
        !mounted) {
      return;
    }
    final name = await _svc.biometricName();
    if (!mounted) return;
    final c = context.mx;
    final yes = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                name == 'wajah'
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
                size: 56,
                iconSize: 30,
              ),
              const SizedBox(height: Sp.lg),
              Text('Buka dengan $name?', style: ctx.text.titleMedium),
              const SizedBox(height: Sp.sm),
              Text(
                'Sentuh sensor untuk membuka MATRIX. Setelah ditinggal 5 menit, MATRIX meminta $name lagi. PIN tetap bisa dipakai.',
                style: ctx.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text('Aktifkan $name'),
                ),
              ),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Pakai PIN saja'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (yes != true) return;
    if (await _svc.authenticate()) {
      await _svc.setBiometricEnabled(true);
      HapticFeedback.mediumImpact();
      if (mounted) {
        showMxSnack(context, 'Buka dengan $name aktif.', tone: Tone.ok);
      }
    } else if (mounted) {
      showMxSnack(
        context,
        'Pindaian belum berhasil. Aktifkan nanti di Akun > Keamanan.',
        tone: Tone.pending,
      );
    }
  }

  void _tap(String d) {
    if (_checking || _pin.length >= _len) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _len) _complete();
  }

  void _backspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _complete() async {
    final pin = _pin;
    switch (widget._mode) {
      case _PinMode.create:
        if (_first == null) {
          setState(() {
            _first = pin;
            _pin = '';
          });
          return;
        }
        if (_first != pin) {
          HapticFeedback.heavyImpact();
          setState(() {
            _error = 'PIN tidak sama. Ulangi dari awal.';
            _first = null;
            _pin = '';
          });
          return;
        }
        await _svc.set(widget.user.id, pin);
        HapticFeedback.mediumImpact();
        await _offerBiometric();
        if (mounted) Navigator.of(context).pop(true);
      case _PinMode.unlock:
      case _PinMode.verify:
        setState(() => _checking = true);
        final ok = await _svc.verify(widget.user.id, pin);
        if (!mounted) return;
        if (ok) {
          HapticFeedback.lightImpact();
          if (widget._mode == _PinMode.unlock) {
            await ref.read(sessionProvider.notifier).unlocked();
          } else {
            Navigator.of(context).pop(true);
          }
          return;
        }
        _wrong++;
        HapticFeedback.heavyImpact();
        if (widget._mode == _PinMode.unlock &&
            _wrong >= PinService.maxAttempts) {
          await ref
              .read(sessionProvider.notifier)
              .logout(
                notice:
                    'PIN salah ${PinService.maxAttempts} kali. Demi keamanan, masuk lagi dengan password.',
              );
          return;
        }
        final left = PinService.maxAttempts - _wrong;
        setState(() {
          _checking = false;
          _pin = '';
          _error = widget._mode == _PinMode.unlock
              ? 'PIN salah. Sisa $left percobaan.'
              : 'PIN salah.';
        });
    }
  }

  Future<void> _forgot() async {
    if (!widget.hasPin) {
      await ref.read(sessionProvider.notifier).logout();
      return;
    }
    final sure = await confirmDialog(
      context,
      title: 'Lupa PIN?',
      message:
          'PIN di HP ini akan dihapus dan Anda harus masuk lagi dengan username dan password.',
      confirmLabel: 'Hapus PIN & masuk ulang',
      destructive: true,
    );
    if (!sure || !mounted) return;
    await ref
        .read(sessionProvider.notifier)
        .logout(
          notice: 'PIN dihapus. Masuk dengan password lalu buat PIN baru.',
        );
  }

  String get _title => switch (widget._mode) {
    _PinMode.unlock => 'Halo, ${widget.user.firstName}',
    _PinMode.verify => 'Masukkan PIN saat ini',
    _PinMode.create => _first == null ? 'Buat PIN 6 digit' : 'Ulangi PIN',
  };

  String get _subtitle => switch (widget._mode) {
    _PinMode.unlock =>
      _checking
          ? 'Memeriksa sesi ke server…'
          : !widget.hasPin
          ? 'Sentuh sensor $_bioName untuk membuka MATRIX. Bisa juga dengan PIN atau pola kunci HP.'
          : widget.biometric
          ? 'Sentuh sensor $_bioName, atau masukkan PIN'
          : 'Masukkan PIN untuk membuka MATRIX',
    _PinMode.verify => 'Untuk mengubah pengaturan keamanan',
    _PinMode.create =>
      _first == null
          ? 'PIN dipakai membuka aplikasi tanpa password'
          : 'Ketik sekali lagi untuk memastikan',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final isRoot = widget._mode == _PinMode.unlock;
    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            bottomPadding: Sp.xl,
            child: Column(
              children: [
                Row(
                  children: [
                    if (!isRoot)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: c.onHero,
                        tooltip: 'Tutup',
                      ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: Sp.sm),
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isRoot
                      ? const MatrixMark(size: 44)
                      : Icon(
                          Icons.lock_outline_rounded,
                          color: c.primary,
                          size: 30,
                        ),
                ),
                const SizedBox(height: Sp.lg),
                Semantics(
                  header: true,
                  child: Text(
                    _title,
                    style: context.text.headlineSmall?.copyWith(
                      color: c.onHero,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: Sp.xs),
                Text(
                  _subtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: c.onHeroMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.hasPin) const SizedBox(height: Sp.xl),
                if (widget.hasPin)
                  Semantics(
                    label: '${_pin.length} dari $_len digit terisi',
                    liveRegion: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_len, (i) {
                        final filled = i < _pin.length;
                        return AnimatedScale(
                          scale: filled ? 1.15 : 1,
                          duration: Motion.of(context, Motion.fast),
                          child: AnimatedContainer(
                            duration: Motion.of(context, Motion.fast),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? Colors.white : Colors.transparent,
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: filled ? 1 : 0.6,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: Center(
              child: _error == null
                  ? null
                  : Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: context.text.bodyMedium?.copyWith(
                          color: c.alert,
                        ),
                      ),
                    ),
            ),
          ),
          if (isRoot && !widget.hasPin)
            // Tanpa PIN aplikasi: satu target sentuh besar di tengah layar.
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Buka dengan $_bioName',
                  child: GestureDetector(
                    onTap: _checking ? null : _tryBiometric,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: context.mx.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.mx.primary.withValues(alpha: 0.25),
                              width: 6,
                            ),
                          ),
                          child: _checking
                              ? Padding(
                                  padding: const EdgeInsets.all(44),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: context.mx.primary,
                                  ),
                                )
                              : Icon(
                                  _bioName == 'wajah'
                                      ? Icons.face_rounded
                                      : Icons.fingerprint_rounded,
                                  size: 64,
                                  color: context.mx.primary,
                                ),
                        ),
                        const SizedBox(height: Sp.lg),
                        ExcludeSemantics(
                          child: Text(
                            _checking ? 'Membuka…' : 'Ketuk untuk memindai',
                            style: context.text.titleSmall?.copyWith(
                              color: context.mx.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          if (isRoot && widget.biometric && widget.hasPin)
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _checking ? null : _tryBiometric,
                  icon: Icon(
                    _bioName == 'wajah'
                        ? Icons.face_rounded
                        : Icons.fingerprint_rounded,
                  ),
                  label: Text('Buka dengan $_bioName'),
                ),
              ),
            ),
          if (widget.hasPin)
            _Keypad(
              onDigit: _tap,
              onBackspace: _backspace,
              leftAction: isRoot && widget.biometric
                  ? IconButton(
                      onPressed: _tryBiometric,
                      tooltip: 'Buka dengan biometrik',
                      icon: Icon(
                        Icons.fingerprint_rounded,
                        size: 32,
                        color: c.primary,
                      ),
                    )
                  : null,
            ),
          const SizedBox(height: Sp.sm),
          if (isRoot)
            TextButton(
              onPressed: _forgot,
              child: Text(
                widget.hasPin
                    ? 'Lupa PIN? Masuk dengan password'
                    : 'Masuk dengan password',
              ),
            ),
          SizedBox(height: Sp.lg + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.leftAction,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? leftAction;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _Key(label: d, onTap: () => onDigit(d));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final d in row) key(d)],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(width: 76, height: 68, child: Center(child: leftAction)),
              key('0'),
              SizedBox(
                width: 76,
                height: 68,
                child: IconButton(
                  onPressed: onBackspace,
                  tooltip: 'Hapus satu digit',
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox(
      width: 76,
      height: 68,
      child: Center(
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: PressScale(
            onTap: onTap,
            child: Material(
              color: c.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: Center(
                    child: Text(
                      label,
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
