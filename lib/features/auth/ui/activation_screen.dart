import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../session.dart';
import 'auth_scaffold.dart';

/// Aktivasi perangkat (sekali per HP): email kantor -> kode 6 digit dari email.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestActivation(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeStep = true);
      _startResendCooldown();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Masukkan 6 digit kode dari email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .verifyActivation(email: _email.text.trim(), code: _code.text);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(sessionProvider.notifier).loggedIn(user);
    } on ApiException catch (e) {
      _code.clear();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    if (!_codeStep) {
      return AuthScaffold(
        title: 'Aktifkan MATRIX di HP ini',
        subtitle:
            'Masukkan email kantor yang terdaftar di SiLAKES. Kami kirim kode 6 digit ke email tersebut.',
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BusyButton(
              label: 'Kirim kode',
              busyLabel: 'Mengirim kode…',
              busy: _busy,
              onPressed: _sendCode,
            ),
            const SizedBox(height: Sp.sm),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).canPop()
                        ? Navigator.of(context).pop()
                        : ref.read(sessionProvider.notifier).logout(),
              child: const Text('Sudah aktivasi? Masuk dengan username'),
            ),
          ],
        ),
        children: [
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendCode(),
              decoration: const InputDecoration(
                labelText: 'Email kantor',
                hintText: 'nama@email.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Email wajib diisi.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return 'Format email belum benar.';
                }
                return null;
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Sp.lg),
            InlineError(_error!),
          ],
        ],
      );
    }

    final box = PinTheme(
      width: 48,
      height: 56,
      textStyle: context.text.headlineSmall,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: c.line),
      ),
    );
    return AuthScaffold(
      title: 'Masukkan kode aktivasi',
      subtitle:
          'Kode dikirim ke ${_email.text.trim()}. Berlaku 5 menit. Cek folder spam bila tidak ada di kotak masuk.',
      onBack: _busy
          ? null
          : () => setState(() {
              _codeStep = false;
              _error = null;
              _code.clear();
            }),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BusyButton(
            label: 'Aktifkan',
            busyLabel: 'Memeriksa kode…',
            busy: _busy,
            onPressed: _verify,
          ),
          const SizedBox(height: Sp.sm),
          TextButton(
            onPressed: _busy || _resendIn > 0 ? null : _sendCode,
            child: Text(
              _resendIn > 0
                  ? 'Kirim ulang dalam $_resendIn detik'
                  : 'Kirim ulang kode',
            ),
          ),
        ],
      ),
      children: [
        Center(
          child: Pinput(
            controller: _code,
            length: 6,
            autofocus: true,
            defaultPinTheme: box,
            focusedPinTheme: box.copyDecorationWith(
              border: Border.all(color: c.primary, width: 2),
            ),
            errorPinTheme: box.copyDecorationWith(
              border: Border.all(color: c.alert, width: 2),
            ),
            forceErrorState: _error != null,
            onCompleted: (_) => _verify(),
            keyboardType: TextInputType.number,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Sp.lg),
          InlineError(_error!),
        ],
      ],
    );
  }
}
