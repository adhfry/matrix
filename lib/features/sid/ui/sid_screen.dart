import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/mx.dart';
import '../../../core/widgets/signature_pad.dart';
import '../../auth/ui/auth_scaffold.dart';
import '../data/sid_repository.dart';

/// Tanda tangan SID: digambar sendiri di kanvas + setujui ketentuan berversi.
/// Alur sama dengan web (Pengaturan Akun, tab Signature). Dibuka dari menu
/// Akun atau notifikasi "sid" (mis. SINTA butuh SID untuk surat izin).
class SidScreen extends ConsumerStatefulWidget {
  const SidScreen({super.key});

  @override
  ConsumerState<SidScreen> createState() => _SidScreenState();
}

class _SidScreenState extends ConsumerState<SidScreen> {
  final _pad = SignatureController();
  bool _redraw = false;
  bool _agree = false;
  bool _showTerms = false;
  bool _busy = false;
  String? _error;
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _pad.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pad.dispose();
    super.dispose();
  }

  void _reload() {
    _image = null;
    ref.invalidate(sidOverviewProvider);
  }

  Future<void> _save(SidTerms terms) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sidRepositoryProvider)
          .save(await _pad.toPng(), terms.version);
      if (!mounted) return;
      showMxSnack(context, 'SID tersimpan dan siap dipakai.', tone: Tone.ok);
      setState(() {
        _redraw = false;
        _agree = false;
      });
      _pad.clear();
      _reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(SidTerms terms) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sidRepositoryProvider).acceptTerms(terms.version);
      if (!mounted) return;
      showMxSnack(context, 'Ketentuan SID terbaru disetujui.', tone: Tone.ok);
      setState(() => _agree = false);
      _reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sidOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tanda tangan SID')),
      body: async.when(
        loading: () => StateView.loading('Memuat SID…'),
        error: (e, _) =>
            StateView.error(e, onRetry: _reload, title: 'SID gagal dimuat'),
        data: (o) => _body(context, o),
      ),
    );
  }

  Widget _body(BuildContext context, SidOverview o) {
    final s = o.status;
    final drawing = !s.hasSid || _redraw;
    if (s.hasSid && !_redraw) {
      _image ??= ref.read(sidRepositoryProvider).image();
    }
    final c = context.mx;
    return ListView(
      // Saat menggambar, halaman tidak bergulir dari kanvas (Listener di pad).
      padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.xs, Sp.gutter, Sp.xxl),
      children: [
        _StatusHeader(status: s),
        const SizedBox(height: Sp.md),
        if (s.hasSid && !_redraw) ...[
          MxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 140,
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Radii.control),
                    border: Border.all(color: c.line),
                  ),
                  child: FutureBuilder<Uint8List>(
                    future: _image,
                    builder: (context, snap) => snap.hasData
                        ? Image.memory(
                            snap.data!,
                            fit: BoxFit.contain,
                            semanticLabel: 'Tanda tangan SID Anda',
                          )
                        : Center(
                            child: Text(
                              snap.hasError
                                  ? 'Gambar SID belum bisa ditampilkan.'
                                  : 'Memuat gambar…',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: Sp.md),
                _Info(
                  'Nomor SID',
                  (s.id ?? '')
                      .substring(0, (s.id ?? '').length.clamp(0, 8))
                      .toUpperCase(),
                ),
                _Info(
                  'Dibuat',
                  s.createdAt == null
                      ? '-'
                      : '${DateFormat('EEEE, d MMMM y, HH.mm', 'id').format(s.createdAt!)} WIB, lewat ${s.createdVia == 'matrix' ? 'MATRIX' : 'web'}',
                ),
                _Info('Ketentuan disetujui', 'Versi ${s.termsVersion ?? '-'}'),
                _Info('Dipakai', '${s.usageCount} kali'),
                const SizedBox(height: Sp.sm),
                Wrap(
                  spacing: Sp.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _redraw = true;
                        _agree = false;
                        _showTerms = true;
                        _error = null;
                      }),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Gambar ulang SID'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _showTerms = !_showTerms),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: Text(
                        _showTerms ? 'Tutup ketentuan' : 'Baca ketentuan',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.md),
        ],
        if (!s.hasSid && (s.revokedLegacy || s.revokedReason != null)) ...[
          _Notice(
            s.revokedLegacy
                ? 'SID lama Anda tidak berlaku lagi karena SiLAKES memakai alur SID baru. Gambar tanda tangan Anda di bawah ini dan setujui ketentuan terbaru.'
                : 'SID Anda sebelumnya dicabut: ${s.revokedReason}',
          ),
          const SizedBox(height: Sp.md),
        ],
        if (s.state == 'needs_terms' && !_redraw) ...[
          _Notice(
            'Ketentuan SID diperbarui ke versi ${s.latestTerms}. Baca dan setujui ketentuan terbaru agar SID dapat dipakai kembali.',
            pending: true,
          ),
          const SizedBox(height: Sp.md),
        ],
        if (_showTerms || drawing || s.state == 'needs_terms') ...[
          _TermsCard(terms: o.terms),
          const SizedBox(height: Sp.md),
        ],
        if (s.state == 'needs_terms' && !_redraw) ...[
          _AgreeTile(
            value: _agree,
            text: o.terms.agreement,
            onChanged: (v) => setState(() => _agree = v),
          ),
          if (_error != null) InlineError(_error!),
          const SizedBox(height: Sp.md),
          BusyButton(
            label: 'Setujui ketentuan terbaru',
            busyLabel: 'Menyimpan…',
            busy: _busy,
            onPressed: _agree ? () => _accept(o.terms) : null,
          ),
        ],
        if (drawing) ...[
          // Sama dengan langkah tanda tangan surat izin.
          Text(
            _redraw ? 'Gambar ulang tanda tangan' : 'Gambar tanda tangan Anda',
            style: context.text.titleSmall,
          ),
          const SizedBox(height: Sp.xs),
          Text(
            'Gambar tanda tangan Anda di kotak berikut. Tanda tangan ini dipakai untuk daftar hadir rapat dan surat izin.',
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Sp.md),
          SignaturePad(controller: _pad),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _pad.isEmpty ? null : _pad.clear,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Ulangi'),
            ),
          ),
          _AgreeTile(
            value: _agree,
            text: '${o.terms.agreement} (versi ${o.terms.version})',
            onChanged: (v) => setState(() => _agree = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: Sp.sm),
            InlineError(_error!),
          ],
          const SizedBox(height: Sp.md),
          BusyButton(
            label: 'Simpan SID',
            busyLabel: 'Menyimpan…',
            busy: _busy,
            onPressed: !_pad.isEmpty && _agree ? () => _save(o.terms) : null,
          ),
          if (_redraw)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _redraw = false),
              child: const Text('Batal'),
            ),
          if (_pad.isEmpty || !_agree)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(
                'Tombol simpan aktif setelah tanda tangan digambar dan persetujuan dicentang.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});
  final SidStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status.state) {
      'active' => ('Aktif', Tone.ok),
      'needs_terms' => ('Perlu persetujuan ulang', Tone.pending),
      _ => ('Belum dibuat', Tone.neutral),
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            'Signature Identity Digital (SID)',
            style: context.text.titleMedium,
          ),
        ),
        StatusPill(label, tone: tone),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: context.mx.inkMuted,
            ),
          ),
          Text(value, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.pending = false});
  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: pending ? c.pendingContainer : c.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Text(text, style: context.text.bodyMedium?.copyWith(color: c.ink)),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.terms});
  final SidTerms terms;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(terms.title, style: context.text.titleSmall),
          Text(
            'Versi ${terms.version}',
            style: context.text.bodySmall?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Sp.sm),
          Text(terms.intro, style: context.text.bodyMedium),
          for (final sec in terms.sections) ...[
            const SizedBox(height: Sp.md),
            Text(sec.title, style: context.text.labelLarge),
            const SizedBox(height: Sp.xs),
            for (var i = 0; i < sec.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}.', style: context.text.bodyMedium),
                    ),
                    Expanded(
                      child: Text(sec.items[i], style: context.text.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AgreeTile extends StatelessWidget {
  const _AgreeTile({
    required this.value,
    required this.text,
    required this.onChanged,
  });
  final bool value;
  final String text;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(text, style: context.text.bodyMedium),
    );
  }
}
