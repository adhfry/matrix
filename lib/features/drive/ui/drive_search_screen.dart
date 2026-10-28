import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import '../data/drive_repository.dart';
import 'drive_folder_screen.dart';

/// Cari di Dokumen Kantor (judul, nomor, isi dokumen) dan Dokumen Saya.
class DriveSearchScreen extends ConsumerStatefulWidget {
  const DriveSearchScreen({super.key});

  @override
  ConsumerState<DriveSearchScreen> createState() => _DriveSearchScreenState();
}

class _DriveSearchScreenState extends ConsumerState<DriveSearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  DriveSearchResult? _result;
  bool _busy = false;
  String? _error;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _result = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    final seq = ++_seq;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(driveRepositoryProvider).search(q);
      if (mounted && seq == _seq) setState(() => _result = r);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = '$e');
    } finally {
      if (mounted && seq == _seq) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _q,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Telusuri di Dokumen Mutu', border: InputBorder.none),
          onChanged: _changed,
          onSubmitted: (v) => v.trim().length >= 2 ? _run(v.trim()) : null,
        ),
        actions: [
          if (_q.text.isNotEmpty)
            IconButton(
              tooltip: 'Hapus pencarian',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _q.clear();
                setState(() => _result = null);
              },
            ),
        ],
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: _error != null
          ? StateView.error(_error!, onRetry: () => _run(_q.text.trim()))
          : r == null
              ? StateView.empty(
                  icon: Icons.search_rounded,
                  title: 'Cari dokumen',
                  message: 'Ketik judul, nomor SK/SOP, atau kata di dalam dokumen. Contoh: "sop sampling" atau "EP 1".',
                )
              : r.kantor.isEmpty && r.saya.isEmpty
                  ? StateView.empty(icon: Icons.search_off_rounded, title: 'Tidak ada yang cocok', message: 'Coba kata lain atau ejaan yang lebih pendek.')
                  : ListView(
                      children: [
                        if (r.kantor.isNotEmpty) _head(context, 'Dokumen Kantor'),
                        for (final i in r.kantor) DriveTile(item: i),
                        if (r.saya.isNotEmpty) _head(context, 'Dokumen Saya'),
                        for (final i in r.saya) DriveTile(item: i),
                        const SizedBox(height: Sp.xxl),
                      ],
                    ),
    );
  }

  Widget _head(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.lg, Sp.gutter, Sp.xs),
        child: Text(t, style: context.text.titleSmall),
      );
}
