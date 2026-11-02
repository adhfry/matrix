import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/calls/ui/call_history_view.dart';
import 'package:matrix/features/sinta/ui/sinta_views.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('tabel pilihan: "Semua: DM" lalu ubah satu baris, kirim jawaban berformat', (t) async {
    String? sent;
    await t.pumpWidget(
      host(
        SintaViews(
          onAnswer: (s) => sent = s,
          views: [
            {
              'type': 'pilihan',
              'judul': 'Jenis Prolanis',
              'kolom': ['Nama', 'No. Reg'],
              'baris': [
                {'id': '001', 'sel': ['SITI', '001'], 'nilai': null},
                {'id': '002', 'sel': ['BUDI', '002'], 'nilai': 'HT'},
              ],
              'opsi': ['DM', 'HT', 'DM + HT'],
              'kirim': 'Kirim jenis',
            },
          ],
        ),
      ),
    );
    expect(find.text('1/2 terisi'), findsOneWidget);
    await t.tap(find.widgetWithText(ActionChip, 'DM'));
    await t.pump();
    expect(find.text('2/2 terisi'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'HT').last);
    await t.pump();
    await t.tap(find.text('Kirim jenis'));
    await t.pump();
    expect(sent, 'Jawaban Jenis Prolanis: 001 (SITI) = DM; 002 (BUDI) = HT');
    expect(find.text('Terkirim'), findsOneWidget);
  });

  testWidgets('angka, tabel, dan grafik dari server tampil', (t) async {
    await t.pumpWidget(
      host(
        SintaViews(
          onAnswer: (_) {},
          views: [
            {'type': 'angka', 'judul': 'Pasien perempuan', 'nilai': '14.293'},
            {
              'type': 'grafik',
              'jenis': 'pai',
              'judul': 'Jenis kelamin',
              'label': ['Perempuan', 'Laki-laki'],
              'seri': [
                {'nama': 'Jumlah', 'data': [3, 1]},
              ],
            },
            {
              'type': 'tabel',
              'judul': 'Daftar',
              'kolom': ['Nama', 'Umur'],
              'baris': [
                ['SITI', 76],
              ],
            },
          ],
        ),
      ),
    );
    expect(find.text('14.293'), findsOneWidget);
    expect(find.text('3 (75%)'), findsOneWidget);
    expect(find.text('SITI'), findsOneWidget);
    expect(find.text('76'), findsOneWidget);
  });

  test('riwayat panggilan: telepon SINTA tak terjawab dibaca sebagai panggilan masuk terlewat', () {
    final it = CallLogItem.fromJson({
      'id': 's1', 'jenis': 'sinta', 'arah': 'masuk', 'nama': 'SINTA', 'grup': false,
      'status': 'tak_terjawab', 'durasi': null, 'waktu': '2026-11-03T00:30:00Z', 'conversation_id': null,
    });
    expect(it.sinta, isTrue);
    expect(it.missed, isTrue);
    expect(CallHistoryView.duration(185), '3 mnt 5 dtk');
  });
}
