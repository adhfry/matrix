import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/ui/auth_scaffold.dart';
import '../data/scanner_repository.dart';
import '../logic/ktp_image.dart';
import 'scan_camera_screen.dart';

/// Baca KTP (OCR server) -> petugas memeriksa & melengkapi -> simpan pasien.
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({super.key, this.photo});

  /// Null = isi manual tanpa foto.
  final File? photo;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{
    for (final k in [...KtpFields.keys, 'phone', 'email', 'no_bpjs'])
      k: TextEditingController(),
  };
  String? _gender;
  String? _status;
  String? _goldar;
  String? _agama;

  bool _reading = false;
  double _upload = 0;
  String? _ocrError;
  List<KtpCheck> _checks = const [];
  ExistingPatient? _existing;
  bool _checkingNik = false;
  Timer? _nikDebounce;
  bool _saving = false;
  String? _saveError;
  bool _keepPhoto = true;

  static const _agamaList = [
    'ISLAM',
    'KRISTEN',
    'KATOLIK',
    'HINDU',
    'BUDHA',
    'KONGHUCU',
    'KEPERCAYAAN',
  ];
  static const _statusList = [
    'BELUM KAWIN',
    'KAWIN',
    'CERAI HIDUP',
    'CERAI MATI',
  ];

  @override
  void initState() {
    super.initState();
    _c['nik']!.addListener(_onNikChanged);
    if (widget.photo != null) _read();
  }

  @override
  void dispose() {
    _nikDebounce?.cancel();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _read() async {
    setState(() {
      _reading = true;
      _ocrError = null;
      _upload = 0;
    });
    try {
      final r = await ref
          .read(scannerRepositoryProvider)
          .ocr(
            widget.photo!,
            onSendProgress: (s, t) {
              if (t > 0 && mounted) setState(() => _upload = s / t);
            },
          );
      if (!mounted) return;
      _fill(r.fields);
      HapticFeedback.lightImpact();
      setState(() {
        _checks = r.checks;
        _existing = r.existing;
      });
    } on ApiException catch (e) {
      setState(() => _ocrError = e.message);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _fill(KtpFields f) {
    for (final k in KtpFields.keys) {
      final v = f[k];
      if (v == null) continue;
      if (k == 'tgl_lahir') {
        final d = DateTime.tryParse(v);
        _c[k]!.text = d == null
            ? ''
            : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      } else if (_c.containsKey(k)) {
        _c[k]!.text = v;
      }
    }
    _gender = f['gender'];
    _status = _statusList.contains(f['status_perkawinan'])
        ? f['status_perkawinan']
        : null;
    _goldar = f['golongan_darah'];
    final a = f['agama'];
    _agama = a == null
        ? null
        : _agamaList.firstWhere(
            (x) => a.contains(x.substring(0, 4)),
            orElse: () => a,
          );
    if (_agama != null && !_agamaList.contains(_agama)) _agama = null;
  }

  void _onNikChanged() {
    final nik = _c['nik']!.text;
    _nikDebounce?.cancel();
    if (nik.length != 16) {
      if (_existing != null) setState(() => _existing = null);
      return;
    }
    _nikDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _checkingNik = true);
      try {
        final ex = await ref.read(scannerRepositoryProvider).checkNik(nik);
        if (mounted && _c['nik']!.text == nik) setState(() => _existing = ex);
      } on ApiException {
        // cek ulang terjadi saat simpan
      } finally {
        if (mounted) setState(() => _checkingNik = false);
      }
    });
  }

  String? _iso(String ddmmyyyy) {
    final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(ddmmyyyy.trim());
    if (m == null) return null;
    return '${m.group(3)}-${m.group(2)}-${m.group(1)}';
  }

  Future<void> _pickDob() async {
    final current =
        DateTime.tryParse(_iso(_c['tgl_lahir']!.text) ?? '') ??
        decodeNik(_c['nik']!.text).birth ??
        DateTime(1990);
    final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Tanggal lahir',
    );
    if (d != null) {
      setState(
        () => _c['tgl_lahir']!.text =
            '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}',
      );
    }
  }

  /// Peringatan cek silang NIK dihitung ulang dari isian saat ini.
  String? _nikHint() {
    final nik = _c['nik']!.text;
    final info = decodeNik(nik);
    if (info.birth == null) return null;
    final hints = <String>[];
    final dob = DateTime.tryParse(_iso(_c['tgl_lahir']!.text) ?? '');
    if (dob != null &&
        (dob.day != info.birth!.day ||
            dob.month != info.birth!.month ||
            dob.year % 100 != info.birth!.year % 100)) {
      hints.add('tanggal lahir di NIK ${Fmt.date(info.birth!)}');
    }
    if (_gender != null && _gender != info.gender) {
      hints.add(
        'NIK menunjukkan ${info.gender == 'L' ? 'laki-laki' : 'perempuan'}',
      );
    }
    return hints.isEmpty
        ? null
        : 'Tidak cocok dengan NIK: ${hints.join('; ')}.';
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    if (!_form.currentState!.validate() || _gender == null) {
      setState(
        () => _saveError = _gender == null
            ? 'Pilih jenis kelamin.'
            : 'Periksa kolom yang ditandai merah.',
      );
      return;
    }
    if (_existing != null) {
      setState(
        () => _saveError =
            'NIK ini sudah terdaftar atas nama ${_existing!.name}.',
      );
      return;
    }
    final hint = _nikHint();
    if (hint != null) {
      final go = await confirmDialog(
        context,
        title: 'Data tidak cocok dengan NIK',
        message: '$hint\n\nTetap simpan seperti yang tertulis di KTP?',
        confirmLabel: 'Tetap simpan',
      );
      if (!go || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      String? t(String k) =>
          _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim().toUpperCase();
      final saved = await ref.read(scannerRepositoryProvider).save({
        'nik': _c['nik']!.text.trim(),
        'name': t('name'),
        'tempat_lahir': t('tempat_lahir'),
        'tgl_lahir': _iso(_c['tgl_lahir']!.text),
        'gender': _gender,
        'alamat': t('alamat'),
        'rt_rw': t('rt_rw'),
        'kel_desa': t('kel_desa'),
        'kecamatan': t('kecamatan'),
        'agama': _agama,
        'status_perkawinan': _status,
        'pekerjaan': t('pekerjaan'),
        'golongan_darah': _goldar,
        'phone': _c['phone']!.text.trim(),
        'email': _c['email']!.text.trim().isEmpty
            ? null
            : _c['email']!.text.trim(),
        'no_bpjs': _c['no_bpjs']!.text.trim().isEmpty
            ? null
            : _c['no_bpjs']!.text.trim(),
      }, ktpPhoto: _keepPhoto ? widget.photo : null);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.invalidate(myScannedPatientsProvider);
      await _showSaved(saved);
    } on ApiException catch (e) {
      setState(
        () => _saveError = e.fieldErrors.isNotEmpty
            ? e.fieldErrors.values.join('\n')
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSaved(SavedPatient p) async {
    final c = context.mx;
    final next = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: c.primaryBright,
                size: 40,
              ),
              const SizedBox(height: Sp.md),
              Text('Pasien terdaftar', style: ctx.text.titleMedium),
              const SizedBox(height: Sp.xs),
              Text(p.name, style: ctx.text.bodyLarge),
              const SizedBox(height: Sp.lg),
              Text(
                'Nomor registrasi',
                style: ctx.text.labelSmall?.copyWith(color: c.inkMuted),
              ),
              SelectableText(
                p.noReg,
                style: ctx.text.displaySmall?.copyWith(fontFeatures: tabular),
              ),
              const SizedBox(height: Sp.xs),
              Text('NIK ${p.nikMasked}', style: ctx.text.bodySmall),
              const SizedBox(height: Sp.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Scan pasien berikutnya'),
                ),
              ),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (next == true) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ScanCameraScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  KtpCheck? _checkFor(String field) =>
      _checks.where((c) => c.field == field).firstOrNull;

  InputDecoration _dec(
    String field,
    String label, {
    String? hint,
    Widget? suffix,
  }) {
    final check = _checkFor(field);
    final c = context.mx;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      helperText: check?.message,
      helperMaxLines: 2,
      helperStyle: context.text.bodySmall?.copyWith(
        color: check == null ? null : (check.isError ? c.alert : c.pending),
      ),
      enabledBorder: check == null
          ? null
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(
                color: check.isError ? c.alert : c.pending,
                width: 1.5,
              ),
            ),
    );
  }

  Widget _text(
    String k,
    String label, {
    String? hint,
    bool required = false,
    TextInputType? type,
    int? maxLength,
    List<TextInputFormatter>? fmt,
    String? Function(String)? validate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: TextFormField(
        controller: _c[k],
        keyboardType: type,
        maxLength: maxLength,
        inputFormatters: fmt,
        textCapitalization: type == null
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: _dec(k, required ? '$label *' : label, hint: hint),
        onChanged: (_) {
          if (_checkFor(k) != null) {
            setState(
              () => _checks = _checks.where((c) => c.field != k).toList(),
            );
          }
        },
        validator: (v) {
          final t = v?.trim() ?? '';
          if (required && t.isEmpty) return '$label wajib diisi.';
          return validate?.call(t);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final nikHint = _nikHint();
    final errors = _checks.where((x) => x.isError).length;
    final warns = _checks.where((x) => !x.isError).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.photo == null ? 'Isi data pasien' : 'Periksa hasil baca',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xl),
          children: [
            if (widget.photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: AspectRatio(
                  aspectRatio: ktpAspect,
                  child: Image.file(
                    widget.photo!,
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto KTP',
                  ),
                ),
              ),
              const SizedBox(height: Sp.md),
              if (_reading)
                MxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _upload < 1
                            ? 'Mengirim foto… ${(_upload * 100).round()}%'
                            : 'Membaca KTP…',
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: Sp.sm),
                      _upload < 1
                          ? MxProgress(value: _upload)
                          : const LinearProgressIndicator(),
                      const SizedBox(height: Sp.sm),
                      Text(
                        'Biasanya 3–8 detik.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                )
              else if (_ocrError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InlineError(_ocrError!),
                    const SizedBox(height: Sp.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _read,
                            child: const Text('Baca ulang'),
                          ),
                        ),
                        const SizedBox(width: Sp.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ScanCameraScreen(),
                                  ),
                                ),
                            child: const Text('Foto ulang'),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else if (_checks.isNotEmpty)
                StatusPill(
                  errors > 0
                      ? '$errors kolom perlu diisi${warns > 0 ? ', $warns perlu dicek' : ''}'
                      : '$warns kolom perlu dicek',
                  tone: errors > 0 ? Tone.alert : Tone.pending,
                  icon: Icons.fact_check_outlined,
                )
              else
                const StatusPill(
                  'Semua kolom terbaca. Tetap periksa sebelum simpan.',
                  tone: Tone.ok,
                  icon: Icons.check_rounded,
                ),
              const SizedBox(height: Sp.lg),
            ],
            if (_existing != null) ...[
              Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(
                  color: c.pendingContainer,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.how_to_reg_outlined, color: c.pending),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Text(
                        'NIK sudah terdaftar: ${_existing!.name}, no. reg ${_existing!.noReg}${_existing!.registeredAt != null ? ' (sejak ${_existing!.registeredAt})' : ''}. Pasien tidak perlu didaftarkan lagi.',
                        style: context.text.bodyMedium?.copyWith(color: c.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.lg),
            ],
            AbsorbPointer(
              absorbing: _reading,
              child: Opacity(
                opacity: _reading ? 0.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Identitas (sesuai KTP)'),
                    TextFormField(
                      controller: _c['nik'],
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: context.text.bodyLarge?.copyWith(
                        fontFeatures: tabular,
                        letterSpacing: 1,
                      ),
                      decoration: _dec(
                        'nik',
                        'NIK *',
                        suffix: _checkingNik
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      validator: (v) =>
                          (v ?? '').length != 16 ? 'NIK harus 16 digit.' : null,
                      onChanged: (_) => setState(
                        () => _checks = _checks
                            .where((c) => c.field != 'nik')
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: Sp.md),
                    _text('name', 'Nama lengkap', required: true),
                    _text('tempat_lahir', 'Tempat lahir', required: true),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.md),
                      child: TextFormField(
                        controller: _c['tgl_lahir'],
                        readOnly: true,
                        onTap: _pickDob,
                        decoration: _dec(
                          'tgl_lahir',
                          'Tanggal lahir *',
                          hint: 'HH-BB-TTTT',
                          suffix: const Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (v) => _iso(v ?? '') == null
                            ? 'Tanggal lahir wajib diisi.'
                            : null,
                      ),
                    ),
                    Text('Jenis kelamin *', style: context.text.labelMedium),
                    const SizedBox(height: Sp.sm),
                    SegmentedButton<String>(
                      emptySelectionAllowed: true,
                      segments: const [
                        ButtonSegment(value: 'L', label: Text('Laki-laki')),
                        ButtonSegment(value: 'P', label: Text('Perempuan')),
                      ],
                      selected: {?_gender},
                      onSelectionChanged: (s) =>
                          setState(() => _gender = s.firstOrNull),
                    ),
                    if (nikHint != null) ...[
                      const SizedBox(height: Sp.sm),
                      Text(
                        nikHint,
                        style: context.text.bodySmall?.copyWith(
                          color: c.pending,
                        ),
                      ),
                    ],
                    const SizedBox(height: Sp.lg),
                    _text('alamat', 'Alamat', required: true),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _text('rt_rw', 'RT/RW', hint: '001/002'),
                        ),
                        const SizedBox(width: Sp.sm),
                        Expanded(flex: 3, child: _text('kel_desa', 'Kel/Desa')),
                      ],
                    ),
                    _text('kecamatan', 'Kecamatan'),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _agama,
                            isExpanded: true,
                            decoration: _dec('agama', 'Agama'),
                            items: [
                              for (final a in _agamaList)
                                DropdownMenuItem(value: a, child: Text(a)),
                            ],
                            onChanged: (v) => setState(() => _agama = v),
                          ),
                        ),
                        const SizedBox(width: Sp.sm),
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<String>(
                            initialValue: _goldar,
                            decoration: const InputDecoration(
                              labelText: 'Gol. darah',
                            ),
                            items: [
                              for (final g in const ['A', 'B', 'AB', 'O'])
                                DropdownMenuItem(value: g, child: Text(g)),
                            ],
                            onChanged: (v) => setState(() => _goldar = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.md),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: _dec(
                        'status_perkawinan',
                        'Status perkawinan',
                      ),
                      items: [
                        for (final s in _statusList)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    const SizedBox(height: Sp.md),
                    _text('pekerjaan', 'Pekerjaan'),
                    const SizedBox(height: Sp.sm),
                    const SectionTitle(
                      'Kontak',
                      subtitle: 'Tidak ada di KTP, tanyakan ke pasien',
                    ),
                    _text(
                      'phone',
                      'Nomor HP',
                      required: true,
                      type: TextInputType.phone,
                      maxLength: 15,
                      fmt: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                      validate: (t) =>
                          RegExp(r'^(\+62|62|0)8\d{7,12}$').hasMatch(t)
                          ? null
                          : 'Format HP: 08xxxxxxxxxx.',
                    ),
                    _text(
                      'email',
                      'Email (opsional)',
                      type: TextInputType.emailAddress,
                      validate: (t) =>
                          t.isEmpty ||
                              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                          ? null
                          : 'Format email belum benar.',
                    ),
                    _text(
                      'no_bpjs',
                      'No. BPJS (opsional)',
                      type: TextInputType.number,
                      fmt: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    if (widget.photo != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _keepPhoto,
                        onChanged: (v) => setState(() => _keepPhoto = v),
                        title: const Text('Simpan foto KTP ke data pasien'),
                        subtitle: const Text(
                          'Untuk verifikasi petugas pendaftaran',
                        ),
                      ),
                    if (_saveError != null) ...[
                      const SizedBox(height: Sp.md),
                      InlineError(_saveError!),
                    ],
                    const SizedBox(height: Sp.lg),
                    BusyButton(
                      label: 'Simpan pasien',
                      busyLabel: 'Menyimpan ke SiLAKES…',
                      busy: _saving,
                      onPressed: _existing != null ? null : _save,
                      icon: Icons.save_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
