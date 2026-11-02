import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tampilan data di jawaban SINTA (sama dengan web, SintaTampilan.vue):
/// tabel, grafik (batang, pai, garis), angka, dan tabel pilihan interaktif.
/// Data tabel/grafik dari kueri disusun server, bukan dikarang AI. Jawaban
/// tabel pilihan dikirim lewat [onAnswer] sebagai pesan berikutnya:
/// `Jawaban judul: id = opsi; ...`.
class SintaViews extends StatelessWidget {
  const SintaViews({
    super.key,
    required this.views,
    required this.onAnswer,
    this.disabled = false,
  });

  final List<Map<String, dynamic>> views;
  final ValueChanged<String> onAnswer;
  final bool disabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final v in views)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _Card(
            child: switch (v['type']) {
              'angka' => _Number(v),
              'tabel' => _Table(v),
              'grafik' => _Chart(v),
              'pilihan' => _Choice(v, onAnswer: onAnswer, disabled: disabled),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
    ],
  );
}

const _navy = Color(0xFF0B2D5B);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF475569);
const _line = Color(0xFFE2E8F0);
const _palette = [
  Color(0xFF0B4A8B),
  Color(0xFF0E9F8A),
  Color(0xFFD97706),
  Color(0xFFB42318),
  Color(0xFF6941C6),
  Color(0xFF0284C7),
];

String _fmt(Object? v) {
  if (v == null) return '–';
  if (v is num) {
    final whole = v == v.roundToDouble();
    final s = whole ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
    // Pemisah ribuan titik.
    final parts = s.split(',');
    final buf = StringBuffer();
    final digits = parts[0].replaceAll('-', '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${parts[0].startsWith('-') ? '-' : ''}$buf${parts.length > 1 ? ',${parts[1]}' : ''}';
  }
  return '$v';
}

List<Object?> _list(Object? v) => v is List ? v : const [];

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String? text;

  @override
  Widget build(BuildContext context) => (text ?? '').isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text!, style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4)),
        );
}

class _Number extends StatelessWidget {
  const _Number(this.v);
  final Map<String, dynamic> v;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Title('${v['judul'] ?? ''}'),
      Text(
        '${v['nilai'] ?? ''}',
        style: const TextStyle(color: _navy, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
      ),
      _Note(v['keterangan'] as String?),
    ],
  );
}

/// Tabel bergulir ke samping; kolom angka rata kanan.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.rows, this.numbered = true});
  final List<String> columns;
  final List<List<Object?>> rows;
  final bool numbered;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 320),
    child: Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 48,
            horizontalMargin: 8,
            columnSpacing: 14,
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
            border: const TableBorder.symmetric(inside: BorderSide(color: _line, width: 0.6)),
            headingTextStyle: const TextStyle(color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: _ink, fontSize: 12.5),
            columns: [
              if (numbered) const DataColumn(label: Text('#'), numeric: true),
              for (var i = 0; i < columns.length; i++)
                DataColumn(
                  label: Text(columns[i]),
                  numeric: rows.isNotEmpty && i < rows.first.length && rows.first[i] is num,
                ),
            ],
            rows: [
              for (final (n, r) in rows.indexed)
                DataRow(
                  cells: [
                    if (numbered) DataCell(Text('${n + 1}', style: const TextStyle(color: Color(0xFF64748B)))),
                    for (var i = 0; i < columns.length; i++) DataCell(Text(_fmt(i < r.length ? r[i] : null))),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table(this.v);
  final Map<String, dynamic> v;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Title('${v['judul'] ?? ''}'),
      _Grid(
        columns: [for (final c in _list(v['kolom'])) '$c'],
        rows: [for (final r in _list(v['baris'])) _list(r).toList()],
      ),
      _Note(v['catatan'] as String?),
    ],
  );
}

// ---------------------------------------------------------------- grafik

class _Chart extends StatefulWidget {
  const _Chart(this.v);
  final Map<String, dynamic> v;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final labels = [for (final l in _list(v['label'])) '$l'];
    final series = [
      for (final s in _list(v['seri']))
        if (s is Map)
          (
            name: '${s['nama'] ?? ''}',
            data: [for (final x in _list(s['data'])) x is num ? x.toDouble() : 0.0],
          ),
    ];
    if (labels.isEmpty || series.isEmpty) return const SizedBox.shrink();
    final tabel = v['tabel'] is Map ? v['tabel'] as Map : null;
    final kind = '${v['jenis']}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title('${v['judul'] ?? ''}'),
        Semantics(
          label: 'Grafik ${v['judul'] ?? ''}: '
              '${[for (var i = 0; i < labels.length; i++) '${labels[i]} ${_fmt(series.first.data.length > i ? series.first.data[i] : 0)}'].join(', ')}',
          child: ExcludeSemantics(
            child: switch (kind) {
              'pai' => _Pie(labels: labels, values: series.first.data),
              'garis' => _Line(labels: labels, series: series),
              _ => _Bars(labels: labels, series: series),
            },
          ),
        ),
        if (series.length > 1 && kind != 'pai') _Legend(names: [for (final s in series) s.name]),
        _Note(v['catatan'] as String?),
        if (tabel != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _table = !_table),
              child: Text(_table ? 'Sembunyikan tabel' : 'Lihat tabel'),
            ),
          ),
          if (_table)
            _Grid(
              numbered: false,
              columns: [for (final c in _list(tabel['kolom'])) '$c'],
              rows: [for (final r in _list(tabel['baris'])) _list(r).toList()],
            ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final (i, n) in names.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _palette[i % _palette.length], borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text(n, style: const TextStyle(fontSize: 11.5, color: _muted)),
            ],
          ),
      ],
    ),
  );
}

/// Batang mendatar: label, batang, angka (cocok untuk layar sempit).
class _Bars extends StatelessWidget {
  const _Bars({required this.labels, required this.series});
  final List<String> labels;
  final List<({String name, List<double> data})> series;

  @override
  Widget build(BuildContext context) {
    final max = series.expand((s) => s.data).fold<double>(0, math.max);
    return Column(
      children: [
        for (var i = 0; i < labels.length && i < 40; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(labels[i], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _ink)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      for (final (si, s) in series.indexed)
                        Padding(
                          padding: EdgeInsets.only(bottom: si < series.length - 1 ? 2 : 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    final value = i < s.data.length ? s.data[i] : 0.0;
                                    final w = max <= 0 ? 0.0 : box.maxWidth * (value / max);
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: math.max(w, value > 0 ? 3.0 : 0.0),
                                        height: series.length > 1 ? 9 : 14,
                                        decoration: BoxDecoration(
                                          color: _palette[si % _palette.length],
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  _fmt(i < s.data.length ? s.data[i] : 0),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11.5, color: _ink, fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.labels, required this.values});
  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(painter: _PiePainter(values)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _palette[i % _palette.length], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Expanded(child: Text(labels[i], style: const TextStyle(fontSize: 12, color: _ink))),
                      Text(
                        '${_fmt(i < values.length ? values[i] : 0)}${total > 0 ? ' (${((i < values.length ? values[i] : 0) / total * 100).round()}%)' : ''}',
                        style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      canvas.drawArc(rect.deflate(8), start, sweep, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = _palette[i % _palette.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.values != values;
}

class _Line extends StatelessWidget {
  const _Line({required this.labels, required this.series});
  final List<String> labels;
  final List<({String name, List<double> data})> series;

  @override
  Widget build(BuildContext context) {
    final max = series.expand((s) => s.data).fold<double>(0, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tertinggi ${_fmt(max)}', style: const TextStyle(fontSize: 11, color: _muted)),
        const SizedBox(height: 4),
        SizedBox(height: 140, child: CustomPaint(painter: _LinePainter(series, max))),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(labels.first, style: const TextStyle(fontSize: 10.5, color: _muted))),
            if (labels.length > 2)
              Text(labels[labels.length ~/ 2], style: const TextStyle(fontSize: 10.5, color: _muted)),
            Expanded(child: Text(labels.last, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: _muted))),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.series, this.max);
  final List<({String name, List<double> data})> series;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _line
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = size.height * g / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (max <= 0) return;
    for (final (si, s) in series.indexed) {
      if (s.data.isEmpty) continue;
      final step = s.data.length > 1 ? size.width / (s.data.length - 1) : 0.0;
      final path = Path();
      for (var i = 0; i < s.data.length; i++) {
        final p = Offset(step * i, size.height - size.height * (s.data[i] / max));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      final paint = Paint()
        ..color = _palette[si % _palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
      if (s.data.length <= 31) {
        for (var i = 0; i < s.data.length; i++) {
          canvas.drawCircle(Offset(step * i, size.height - size.height * (s.data[i] / max)), 2.5, Paint()..color = paint.color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.series != series || old.max != max;
}

// ---------------------------------------------------------------- tabel pilihan

class _Choice extends StatefulWidget {
  const _Choice(this.v, {required this.onAnswer, required this.disabled});
  final Map<String, dynamic> v;
  final ValueChanged<String> onAnswer;
  final bool disabled;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  late final Map<String, String?> _picks = {
    for (final r in _list(widget.v['baris']))
      if (r is Map) '${r['id']}': r['nilai'] as String?,
  };

  bool get _sent => widget.v['terkirim'] == true;

  void _submit() {
    final rows = [for (final r in _list(widget.v['baris'])) if (r is Map) r];
    final parts = [
      for (final r in rows)
        '${r['id']}${_list(r['sel']).isNotEmpty && '${_list(r['sel']).first}' != '${r['id']}' ? ' (${_list(r['sel']).first})' : ''} = ${_picks['${r['id']}']}',
    ];
    setState(() => widget.v['terkirim'] = true);
    widget.onAnswer('Jawaban ${widget.v['judul']}: ${parts.join('; ')}');
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final opsi = [for (final o in _list(v['opsi'])) '$o'];
    final rows = [for (final r in _list(v['baris'])) if (r is Map) r];
    final done = _picks.values.where((x) => x != null).length;
    final locked = _sent || widget.disabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title('${v['judul'] ?? ''}'),
        if ('${v['pertanyaan'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${v['pertanyaan']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4)),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Semua:', style: TextStyle(fontSize: 12, color: _muted)),
            for (final o in opsi)
              ActionChip(
                label: Text(o),
                onPressed: locked ? null : () => setState(() => _picks.updateAll((_, _) => o)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: _line),
            itemBuilder: (context, i) {
              final r = rows[i];
              final id = '${r['id']}';
              final sel = [for (final c in _list(r['sel'])) '$c'];
              final pick = _picks[id];
              return Container(
                color: pick == null ? const Color(0xFFFFFBEB) : null,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sel.isNotEmpty ? sel.first : id, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w600)),
                    if (sel.length > 1)
                      Text(sel.skip(1).where((x) => x.isNotEmpty && x != '-').join(' · '), style: const TextStyle(fontSize: 11.5, color: _muted)),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final o in opsi)
                          ChoiceChip(
                            label: Text(o),
                            selected: pick == o,
                            onSelected: locked ? null : (_) => setState(() => _picks[id] = o),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('$done/${rows.length} terisi', style: const TextStyle(fontSize: 12, color: _muted))),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _navy, minimumSize: const Size(0, 44)),
              onPressed: locked || done < rows.length ? null : _submit,
              icon: Icon(_sent ? Icons.check_rounded : Icons.send_rounded, size: 18),
              label: Text(_sent ? 'Terkirim' : '${v['kirim'] ?? 'Kirim jawaban'}'),
            ),
          ],
        ),
      ],
    );
  }
}
