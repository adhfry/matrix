import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/ui/auth_scaffold.dart';
import '../data/identity_repository.dart';

const _digits = {
  'nik',
  'nip',
  'npwp',
  'bpjs_kesehatan',
  'bpjs_ketenagakerjaan',
  'bank_rekening',
  'ktp_kode_pos',
  'dom_kode_pos',
};
const _phones = {'phone'};
const _domisili = {
  'dom_alamat',
  'dom_rt_rw',
  'dom_kel_desa',
  'dom_kecamatan',
  'dom_kabupaten',
  'dom_provinsi',
  'dom_kode_pos',
};

/// Data diri pegawai sesuai KTP + domisili + kepegawaian. Wajib 100%: kolom
/// yang memang tidak dimiliki dicentang "Tidak memiliki" (tercatat di server).
class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  IdentityData? _data;
  final _text = <String, TextEditingController>{};
  final _choice = <String, String?>{};
  final _declared = <String, bool>{};
  bool _samaKtp = false;
  bool _saving = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(IdentityData d) {
    _data = d;
    _samaKtp = d.domisiliSamaKtp;
    for (final f in d.fields) {
      _declared[f.key] = f.declared;
      if (f.optionMap != null) {
        _choice[f.key] = f.value;
      } else {
        (_text[f.key] ??= TextEditingController()).text = f.value ?? '';
      }
    }
  }

  Future<void> _pickDate(IdentityField f) async {
    final current =
        DateTime.tryParse(_text[f.key]?.text ?? '') ?? DateTime(1990);
    // Batas sama dengan aturan Laravel: after:1940-01-01, before:today.
    final now = DateTime.now();
    final last = DateTime(now.year, now.month, now.day - 1);
    final first = DateTime(1940, 1, 2);
    final d = await showDatePicker(
      context: context,
      initialDate: current.isAfter(last)
          ? last
          : (current.isBefore(first) ? first : current),
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: f.label,
    );
    if (d != null) {
      setState(
        () => _text[f.key]!.text =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    setState(() {
      _saving = true;
      _errors = const {};
    });
    final values = <String, String?>{};
    final decl = <String, bool>{};
    for (final f in d.fields.where((f) => !f.readonly)) {
      if (f.declarable) decl[f.key] = _declared[f.key] ?? false;
      if (_declared[f.key] ?? false) continue;
      if (_samaKtp && _domisili.contains(f.key)) continue;
      values[f.key] = f.optionMap != null ? _choice[f.key] : _text[f.key]?.text;
    }
    try {
      final res = await ref
          .read(identityRepositoryProvider)
          .save(values: values, declarations: decl, domisiliSamaKtp: _samaKtp);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _load(res.data));
      ref.invalidate(identityProvider);
      showMxSnack(
        context,
        res.message,
        tone: res.data.complete ? Tone.ok : Tone.neutral,
      );
      if (res.data.complete) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.fieldErrors);
      showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(identityProvider);
    if (_data == null && async.hasValue) _load(async.value!);
    final d = _data;
    final c = context.mx;

    return Scaffold(
      body: d == null
          ? (async.hasError
                ? StateView.error(
                    async.error!,
                    onRetry: () => ref.invalidate(identityProvider),
                  )
                : StateView.loading('Memuat data diri…'))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          HeroHeader(
                            bottomPadding: Sp.xl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: c.onHero,
                                  tooltip: 'Kembali',
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                ),
                                const SizedBox(height: Sp.sm),
                                Row(
                                  children: [
                                    RingProgress(
                                      value: d.completeness / 100,
                                      size: 84,
                                      stroke: 8,
                                      onHero: true,
                                      center: Text(
                                        '${d.completeness}%',
                                        style: context.text.titleMedium
                                            ?.copyWith(
                                              color: c.onHero,
                                              fontFeatures: tabular,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: Sp.lg),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Data diri',
                                            style: context.text.headlineSmall
                                                ?.copyWith(color: c.onHero),
                                          ),
                                          Text(
                                            d.complete
                                                ? 'Sudah lengkap. Perbarui bila ada perubahan.'
                                                : '${d.missing.length} kolom belum diisi. Kolom yang memang tidak Anda miliki, centang "Tidak memiliki".',
                                            style: context.text.bodySmall
                                                ?.copyWith(
                                                  color: c.onHeroMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Sp.gutter,
                              Sp.lg,
                              Sp.gutter,
                              Sp.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final section in d.sections.entries) ...[
                                  SectionTitle(section.value),
                                  if (section.key == 'domisili')
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: Sp.sm,
                                      ),
                                      child: MxCard(
                                        padding: EdgeInsets.zero,
                                        child: SwitchListTile(
                                          value: _samaKtp,
                                          onChanged: (v) =>
                                              setState(() => _samaKtp = v),
                                          title: const Text(
                                            'Sama dengan alamat KTP',
                                          ),
                                          subtitle: const Text(
                                            'Matikan bila Anda tinggal di alamat lain',
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!(section.key == 'domisili' && _samaKtp))
                                    MxCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final f in d.fields.where(
                                            (f) => f.section == section.key,
                                          ))
                                            _field(f),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: Sp.xl),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const StatusScrim(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.gutter,
                      Sp.sm,
                      Sp.gutter,
                      Sp.md,
                    ),
                    child: BusyButton(
                      label: 'Simpan data diri',
                      busyLabel: 'Menyimpan…',
                      busy: _saving,
                      onPressed: _save,
                      icon: Icons.save_outlined,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(IdentityField f) {
    final c = context.mx;
    final declared = _declared[f.key] ?? false;
    final error = _errors[f.key];
    final options = f.optionMap;
    final missing =
        !f.readonly &&
        !declared &&
        (options != null
            ? (_choice[f.key] ?? '').isEmpty
            : (_text[f.key]?.text ?? '').trim().isEmpty);

    Widget input;
    if (options != null) {
      input = DropdownButtonFormField<String>(
        initialValue: options.containsKey(_choice[f.key])
            ? _choice[f.key]
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: f.label,
          helperText: f.hint,
          errorText: error,
          helperMaxLines: 2,
        ),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: declared || f.readonly
            ? null
            : (v) => setState(() => _choice[f.key] = v),
      );
    } else {
      final ctrl = _text[f.key]!;
      input = TextFormField(
        controller: ctrl,
        readOnly: f.readonly || f.isDate,
        enabled: !declared,
        onTap: f.isDate && !f.readonly ? () => _pickDate(f) : null,
        onChanged: (_) => setState(() {}),
        keyboardType: _digits.contains(f.key)
            ? TextInputType.number
            : (_phones.contains(f.key)
                  ? TextInputType.phone
                  : TextInputType.text),
        inputFormatters: [
          if (_digits.contains(f.key)) FilteringTextInputFormatter.digitsOnly,
          if (f.key.endsWith('rt_rw')) _RtRwFormatter(),
        ],
        textCapitalization: _digits.contains(f.key) || _phones.contains(f.key)
            ? TextCapitalization.none
            : TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: f.label,
          hintText: f.key.endsWith('rt_rw') ? '001/002' : null,
          helperText: f.readonly
              ? f.hint
              : (f.isDate && ctrl.text.isNotEmpty
                    ? Fmt.dayLong(DateTime.parse(ctrl.text))
                    : f.hint),
          helperMaxLines: 2,
          errorText: error,
          suffixIcon: f.isDate
              ? const Icon(Icons.calendar_today_outlined)
              : (f.readonly
                    ? const Icon(Icons.lock_outline_rounded, size: 18)
                    : null),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: input),
              if (missing)
                Padding(
                  padding: const EdgeInsets.only(left: Sp.sm, top: 18),
                  child: Tooltip(
                    message: 'Belum diisi',
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: c.pending,
                    ),
                  ),
                ),
            ],
          ),
          if (f.declarable)
            InkWell(
              onTap: () => setState(() => _declared[f.key] = !declared),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: declared,
                        onChanged: (v) =>
                            setState(() => _declared[f.key] = v ?? false),
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    Text(
                      f.key == 'golongan_darah'
                          ? 'Tidak tahu'
                          : 'Tidak memiliki',
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mengubah "1" -> "001/" dst. supaya RT/RW selalu berformat 001/002.
class _RtRwFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 6 ? digits.substring(0, 6) : digits;
    final text = d.length <= 3 ? d : '${d.substring(0, 3)}/${d.substring(3)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
