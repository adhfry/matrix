import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/session.dart';
import '../pin_service.dart';

enum _PinMode { unlock, create, verify }

/// Satu layar untuk membuka kunci, membuat, dan memverifikasi PIN 6 digit.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen._(this._mode, {required this.user, this.biometric = false});

  /// Layar akar saat aplikasi terkunci.
  factory PinScreen.unlock({required AppUser user, required bool biometric}) =>
      PinScreen._(_PinMode.unlock, user: user, biometric: biometric);

  /// Dibuka dengan Navigator.push; mengembalikan `true` bila PIN tersimpan.
  factory PinScreen.create({required AppUser user}) =>
      PinScreen._(_PinMode.create, user: user);

  /// Konfirmasi PIN lama sebelum ubah/hapus; mengembalikan `true` bila cocok.
  factory PinScreen.verify({required AppUser user}) =>
      PinScreen._(_PinMode.verify, user: user);

  final _PinMode _mode;
  final AppUser user;
  final bool biometric;

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

  PinService get _svc => ref.read(pinServiceProvider);

  @override
  void initState() {
    super.initState();
    if (widget._mode == _PinMode.unlock && widget.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    if (await _svc.authenticate()) {
      HapticFeedback.lightImpact();
      if (mounted) setState(() => _checking = true);
      await ref.read(sessionProvider.notifier).unlocked();
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
                      ? Image.asset(
                          'assets/images/logo_nobg.png',
                          excludeFromSemantics: true,
                        )
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
                const SizedBox(height: Sp.xl),
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
          const Spacer(),
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
              child: const Text('Lupa PIN? Masuk dengan password'),
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
