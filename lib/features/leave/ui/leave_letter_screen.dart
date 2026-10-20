import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/mx.dart';
import '../../../core/widgets/signature_pad.dart';
import '../../auth/ui/auth_scaffold.dart';
import '../data/leave_repository.dart';

/// Isian pengajuan yang diteruskan ke langkah tanda tangan.
class LeaveDraftInput {
  const LeaveDraftInput({
    required this.type,
    required this.subtype,
    required this.start,
    required this.end,
    required this.reason,
    this.attachment,
  });

  final String type;
  final String subtype;
  final DateTime start;
  final DateTime end;
  final String reason;
  final File? attachment;
}

/// Langkah 2: tanda tangan di kanvas, lalu draf surat dibuat server.
class LeaveSignScreen extends ConsumerStatefulWidget {
  const LeaveSignScreen({super.key, required this.input});
  final LeaveDraftInput input;

  @override
  ConsumerState<LeaveSignScreen> createState() => _LeaveSignScreenState();
}

class _LeaveSignScreenState extends ConsumerState<LeaveSignScreen> {
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

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final i = widget.input;
      final id = await ref
          .read(leaveRepositoryProvider)
          .submit(
            type: i.type,
            subtype: i.subtype,
            start: i.start,
            end: i.end,
            reason: i.reason,
            attachment: i.attachment,
            signature: await _pad.toPng(),
          );
      ref.invalidate(leaveMonthProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LeaveLetterScreen(id: id, status: 'draft'),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tanda tangan')),
      // Tidak bergulir: menggeser di kanvas tidak boleh menggulir halaman.
      body: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Steps(current: 1),
            const SizedBox(height: Sp.lg),
            Text(
              'Gambar tanda tangan Anda di kotak berikut. Tanda tangan ditempel pada surat izin yang dibuat otomatis.',
              style: context.text.bodyMedium?.copyWith(
                color: context.mx.inkMuted,
              ),
            ),
            const SizedBox(height: Sp.lg),
            SignaturePad(controller: _pad),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pad.isEmpty ? null : _pad.clear,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Ulangi'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.sm),
              InlineError(_error!),
            ],
            const SizedBox(height: Sp.lg),
            BusyButton(
              label: 'Buat draf surat',
              busyLabel: 'Membuat surat…',
              busy: _busy,
              onPressed: _pad.isEmpty ? null : _create,
            ),
          ],
        ),
      ),
    );
  }
}

/// Langkah 3-4: tinjau draf & ajukan, lalu kirim ke Kepala UPTD. Juga dipakai
/// membuka surat dari riwayat ([status] = draft | submitted | final | closed;
/// closed = ditolak/dibatalkan, surat hanya arsip).
class LeaveLetterScreen extends ConsumerStatefulWidget {
  const LeaveLetterScreen({super.key, required this.id, required this.status});
  final int id;
  final String status;

  /// Hasil pop saat draf dihapus.
  static const deleted = 'deleted';

  @override
  ConsumerState<LeaveLetterScreen> createState() => _LeaveLetterScreenState();
}

class _LeaveLetterScreenState extends ConsumerState<LeaveLetterScreen> {
  late String _status = widget.status;
  Uint8List? _pdf;
  LeaveShare? _share;
  String? _error;
  bool _busy = false;

  /// Langsung disetujui saat diajukan (persetujuan otomatis menyala).
  bool _autoApproved = false;

  LeaveRepository get _repo => ref.read(leaveRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final pdf = await _repo.letter(widget.id);
      final share = _status == 'submitted'
          ? await _repo.share(widget.id)
          : null;
      if (mounted) {
        setState(() {
          _pdf = pdf;
          _share = share ?? _share;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final result = await _repo.submitLetter(widget.id);
      ref.invalidate(leaveMonthProvider);
      ref.invalidate(leaveDetailProvider(widget.id));
      setState(() {
        _status = 'submitted';
        _share = result.share;
        _autoApproved = result.autoApproved;
        _pdf = null;
      });
      if (mounted) {
        showMxSnack(
          context,
          result.autoApproved
              ? 'Pengajuan langsung disetujui. Kirim surat ke Kepala UPTD.'
              : 'Pengajuan terkirim ke admin. Kirim surat ke Kepala UPTD.',
          tone: Tone.ok,
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDraft() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus draf surat?',
      message:
          'Pengajuan ini belum dikirim ke admin. Draf dan tanda tangan akan dihapus.',
      confirmLabel: 'Hapus draf',
    );
    if (!ok) return;
    try {
      await _repo.deleteDraft(widget.id);
      ref.invalidate(leaveMonthProvider);
      // Halaman detail (bila membuka dari sana) ikut ditutup: lihat LeaveDetailScreen.
      if (mounted) Navigator.of(context).pop(LeaveLetterScreen.deleted);
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    }
  }

  /// Lembar bagikan Android dengan berkas PDF (pilih WhatsApp -> Kepala UPTD).
  Future<void> _sharePdf() async {
    final pdf = _pdf;
    if (pdf == null) return;
    await Printing.sharePdf(
      bytes: pdf,
      filename: _share?.fileName ?? 'surat-izin.pdf',
      subject: _share?.text,
    );
  }

  /// WhatsApp langsung ke nomor Kepala UPTD dengan teks + tautan surat.
  Future<void> _sendWhatsApp() async {
    final s = _share;
    if (s == null) return;
    final text = Uri.encodeComponent(s.text);
    final url = s.waNumber == null
        ? 'https://wa.me/?text=$text'
        : 'https://wa.me/${s.waNumber}?text=$text';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (String note, Tone tone) = switch (_status) {
      'draft' => (
        'Periksa isi surat. Bila sudah benar, ajukan; admin akan menerima pemberitahuan.',
        Tone.pending,
      ),
      'submitted' when _autoApproved => (
        'Pengajuan langsung disetujui dan jadwal Anda sudah diperbarui. Kirim surat ini ke Kepala UPTD untuk diketahui.',
        Tone.ok,
      ),
      'submitted' => (
        'Pengajuan terkirim. Kirim surat ini ke Kepala UPTD; setelah disetujui, surat bertanda tangan lengkap tersimpan otomatis.',
        Tone.ok,
      ),
      'closed' => (
        'Pengajuan ini ditolak atau dibatalkan. Surat disimpan sebagai arsip dan tidak perlu dikirim ke Kepala UPTD.',
        Tone.neutral,
      ),
      _ => ('Surat sudah disetujui dan ditandatangani lengkap.', Tone.ok),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Surat izin')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.md),
            child: Column(
              children: [
                _Steps(current: _status == 'draft' ? 2 : 3),
                const SizedBox(height: Sp.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    color: tone.bg(c),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Text(
                    note,
                    style: context.text.bodyMedium?.copyWith(color: tone.fg(c)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? StateView.error(
                    _error!,
                    onRetry: _load,
                    title: 'Surat gagal dimuat',
                  )
                : _pdf == null
                ? StateView.loading('Memuat surat…')
                : PdfPreview(
                    build: (_) async => _pdf!,
                    useActions: false,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfFileName: _share?.fileName,
                    scrollViewDecoration: BoxDecoration(color: c.canvas),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.md,
                Sp.gutter,
                Sp.md,
              ),
              child: switch (_status) {
                'draft' => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _deleteDraft,
                        child: const Text('Hapus draf'),
                      ),
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy || _pdf == null ? null : _submit,
                        child: Text(_busy ? 'Mengirim…' : 'Ajukan surat'),
                      ),
                    ),
                  ],
                ),
                'submitted' => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _pdf == null ? null : _sharePdf,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Kirim berkas ke Kepala UPTD'),
                      ),
                    ),
                    const SizedBox(height: Sp.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _share == null ? null : _sendWhatsApp,
                        icon: const Icon(Icons.chat_outlined),
                        label: Text(
                          _share?.waNumber == null
                              ? 'Kirim tautan lewat WhatsApp'
                              : 'Kirim tautan ke WhatsApp Kepala UPTD',
                        ),
                      ),
                    ),
                  ],
                ),
                _ => SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _pdf == null ? null : _sharePdf,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Bagikan atau simpan PDF'),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Penanda langkah: Isi data -> Tanda tangan -> Tinjau draf -> Kirim.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    const labels = ['Isi data', 'Tanda tangan', 'Tinjau', 'Kirim'];
    return Semantics(
      label: 'Langkah ${current + 1} dari 4: ${labels[current]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= current ? c.primary : c.line,
                ),
              ),
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current ? c.primary : c.line,
                  ),
                  child: i < current
                      ? Icon(Icons.check_rounded, size: 16, color: c.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: context.text.labelSmall?.copyWith(
                            color: i <= current ? c.onPrimary : c.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: context.text.labelSmall?.copyWith(
                    color: i == current ? c.ink : c.inkMuted,
                    fontWeight: i == current ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
