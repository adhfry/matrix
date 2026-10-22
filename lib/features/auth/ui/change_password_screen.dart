import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../session.dart';
import 'auth_scaffold.dart';

/// Ganti password sendiri. [forced]: akun baru atau password diatur ulang admin
/// masih memakai password awal, jadi beranda baru terbuka setelah diganti.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  final bool forced;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  static const _initialPassword = '12345678';

  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      ref.read(sessionProvider.notifier).userUpdated(user);
      if (!widget.forced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password diganti. Gunakan password baru di web dan MATRIX.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, {String? helper}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = switch (ref.watch(sessionProvider)) {
      SessionReady(:final user) => user.firstName,
      _ => null,
    };
    return AuthScaffold(
      title: widget.forced ? 'Ganti password awal' : 'Ganti password',
      subtitle: widget.forced
          ? 'Halo${name == null ? '' : ' $name'}, akun Anda masih memakai password awal dari admin. Buat password baru sebelum melanjutkan.'
          : 'Password baru berlaku untuk SiLAKES web dan MATRIX.',
      onBack: widget.forced ? null : () => Navigator.of(context).pop(),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BusyButton(
            label: 'Simpan password baru',
            busyLabel: 'Menyimpan…',
            busy: _busy,
            onPressed: _submit,
          ),
          if (widget.forced) ...[
            const SizedBox(height: Sp.sm),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(sessionProvider.notifier).logout(),
              child: const Text('Keluar'),
            ),
          ],
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _current,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  decoration: _decoration(
                    'Password saat ini',
                    helper: widget.forced
                        ? 'Password awal yang diberikan admin.'
                        : null,
                  ),
                  validator: (v) => (v?.isEmpty ?? true)
                      ? 'Password saat ini wajib diisi.'
                      : null,
                ),
                const SizedBox(height: Sp.lg),
                TextFormField(
                  controller: _next,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: _decoration(
                    'Password baru',
                    helper: 'Minimal 8 karakter, kombinasi huruf dan angka.',
                  ),
                  validator: (v) {
                    final p = v ?? '';
                    if (p.length < 8) return 'Password baru minimal 8 karakter.';
                    if (p == _initialPassword) {
                      return 'Gunakan password selain password awal.';
                    }
                    if (p == _current.text) {
                      return 'Password baru harus berbeda dari password saat ini.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Sp.lg),
                TextFormField(
                  controller: _repeat,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _decoration('Ulangi password baru'),
                  validator: (v) => v != _next.text
                      ? 'Ulangi password baru dengan sama persis.'
                      : null,
                ),
              ],
            ),
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
