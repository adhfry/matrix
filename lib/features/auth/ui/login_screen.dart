import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../session.dart';
import 'activation_screen.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.lastUsername, this.notice});

  final String? lastUsername;
  final String? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _username = TextEditingController(text: widget.lastUsername);
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
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
          .login(username: _username.text.trim(), password: _password.text);
      ref.read(sessionProvider.notifier).loggedIn(user);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasName = (widget.lastUsername ?? '').isNotEmpty;
    return AuthScaffold(
      title: hasName ? 'Masuk kembali' : 'Masuk ke MATRIX',
      subtitle: 'Gunakan username dan password SiLAKES Anda.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BusyButton(
            label: 'Masuk',
            busyLabel: 'Memeriksa akun…',
            busy: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: Sp.sm),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ActivationScreen(),
                    ),
                  ),
            child: const Text('HP baru? Aktivasi lewat email'),
          ),
        ],
      ),
      children: [
        if (widget.notice != null) ...[
          InlineNotice(widget.notice!),
          const SizedBox(height: Sp.lg),
        ],
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Username wajib diisi.'
                      : null,
                ),
                const SizedBox(height: Sp.lg),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Password wajib diisi.' : null,
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
