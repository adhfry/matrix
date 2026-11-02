import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/shell/required_permissions.dart';
import 'package:matrix/features/sinta/data/sinta_repository.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

  testWidgets('Izin wajib: semua izin tampil, yang belum diberi punya tombol', (
    t,
  ) async {
    final asked = <ReqPerm>[];
    var all = 0;
    await t.pumpWidget(
      host(
        PermissionGate(
          states: {
            ReqPerm.notifikasi: const PermState(granted: false, blocked: false),
            ReqPerm.lokasi: const PermState(granted: true, blocked: false),
            ReqPerm.kamera: const PermState(granted: true, blocked: false),
            ReqPerm.mikrofon: const PermState(granted: false, blocked: true),
            ReqPerm.baterai: const PermState(granted: true, blocked: false),
          },
          busy: null,
          onRequest: asked.add,
          onRequestAll: () => all++,
          onLogout: () {},
        ),
      ),
    );
    expect(find.text('Izin wajib MATRIX'), findsOneWidget);
    for (final p in ReqPerm.values) {
      expect(find.text(p.title), findsOneWidget);
    }
    expect(find.textContaining('2 izin belum diberikan'), findsOneWidget);
    // Ditolak permanen: diarahkan ke Pengaturan.
    expect(find.text('Pengaturan'), findsOneWidget);
    await t.tap(find.text('Izinkan'));
    expect(asked, [ReqPerm.notifikasi]);
    await t.scrollUntilVisible(find.text('Keluar akun'), 200);
    await t.tap(find.text('Izinkan semua'));
    expect(all, 1);
    expect(find.text('Keluar akun'), findsOneWidget);
  });

  test('Laporan izin memakai kunci yang sama dengan server', () {
    final r = RequiredPermissions.report({
      for (final p in ReqPerm.values)
        p: PermState(granted: p != ReqPerm.baterai, blocked: false),
    });
    expect(r.keys, ['notifikasi', 'lokasi', 'kamera', 'mikrofon', 'baterai']);
    expect(r['baterai'], isFalse);
  });

  test('Usulan SINTA: tabel ikut dibaca dan tersimpan untuk riwayat', () {
    final p = SintaProposal.fromJson({
      'id': 'a',
      'title': 'Simpan hasil',
      'confirm_label': 'Simpan',
      'items': [
        {
          'title': 'Hasil',
          'lines': [
            {'label': 'Pasien', 'value': '2'},
          ],
          'after': 'Disimpan ke lembar kerja.',
          'table': {
            'columns': ['Nama', 'GDS'],
            'rows': [
              ['A', 120],
              ['B', null],
            ],
          },
        },
      ],
    });
    final table = p.items.single.table!;
    expect(table.columns, ['Nama', 'GDS']);
    expect(table.rows, [
      ['A', '120'],
      ['B', ''],
    ]);
    p.status = 'done';
    final again = SintaProposal.fromJson(p.toJson());
    expect(again.items.single.table!.rows.first, ['A', '120']);
    expect(p.toJson()['status'], 'done');
  });
}
