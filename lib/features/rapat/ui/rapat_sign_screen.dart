import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/signature_pad.dart';
import '../../auth/ui/auth_scaffold.dart';
import '../data/rapat_repository.dart';

/// Tanda tangan daftar hadir rapat, digambar sendiri di kanvas (sama dengan
/// kanvas surat izin). Pop dengan true setelah tersimpan.
class RapatSignScreen extends ConsumerStatefulWidget {
  const RapatSignScreen({super.key, required this.meeting});
  final Meeting meeting;

  @override
  ConsumerState<RapatSignScreen> createState() => _RapatSignScreenState();
}

class _RapatSignScreenState extends ConsumerState<RapatSignScreen> {
  final _pad = SignatureController();
  bool _busy = false;
  String? _error;

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

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await ref
          .read(rapatRepositoryProvider)
          .sign(widget.meeting.id, await _pad.toPng());
      HapticFeedback.mediumImpact();
      ref.invalidate(todayMeetingsProvider);
      ref.invalidate(meetingDetailProvider(widget.meeting.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Kehadiran tercatat. Terima kasih.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final c = context.mx;
    return Scaffold(
      appBar: AppBar(title: const Text('Tanda tangan kehadiran')),
      // Tidak bergulir: menggeser di kanvas tidak boleh menggulir halaman.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, Sp.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m.title, style: context.text.titleMedium),
              Text(
                '${Fmt.dayLong(m.date)} · ${m.timeRange}',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
              if (m.location != null)
                Text(
                  m.location!,
                  style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                ),
              const SizedBox(height: Sp.lg),
              Text(
                'Gambar tanda tangan Anda di kotak berikut sebagai bukti kehadiran pada rapat ini.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Sp.md),
              SignaturePad(controller: _pad),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pad.isEmpty || _busy ? null : _pad.clear,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Ulangi'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Sp.sm),
                InlineError(_error!),
              ],
              const Spacer(),
              BusyButton(
                label: 'Kirim & hadir',
                busyLabel: 'Menyimpan…',
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: _pad.isEmpty ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
