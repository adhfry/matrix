import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/api/api_client.dart';
import 'package:matrix/core/storage/secure_store.dart';
import 'package:matrix/features/documents/data/document_repository.dart';
import 'package:matrix/features/documents/ui/documents_screen.dart';

class _Repo extends DocumentRepository {
  _Repo() : super(ApiClient(SecureStore()));
  final absent = <(int, bool)>[];
  final removed = <int>[];
  var _cvAbsent = false;
  var _fotoFiles = true;

  @override
  Future<DocOverview> overview() async {
    final items = [
      DocItem.fromJson({
        'type': {'id': 1, 'name': 'Pas foto', 'is_required': true},
        'status': _fotoFiles ? 'ada' : null,
        'files': _fotoFiles
            ? [
                {
                  'id': 10,
                  'name': 'foto.jpg',
                  'size': 120000,
                  'mime': 'image/jpeg',
                  'url': 'https://contoh.test/f.jpg',
                  'uploaded_at': '2026-10-21T01:00:00Z',
                },
              ]
            : [],
      }),
      DocItem.fromJson({
        'type': {'id': 2, 'name': 'Curriculum Vitae (CV)'},
        'status': _cvAbsent ? 'tidak_ada' : null,
        'files': [],
      }),
      DocItem.fromJson({
        'type': {
          'id': 3,
          'name': 'Sertifikat pelatihan',
          'allows_multiple': true,
        },
        'status': null,
        'files': [],
      }),
    ];
    final done = items.where((i) => i.filled).length;
    return DocOverview(
      items: items,
      done: done,
      total: items.length,
      percent: done * 100 ~/ items.length,
      maxBytes: 5 * 1024 * 1024,
    );
  }

  @override
  Future<void> setAbsent(int typeId, bool value) async {
    absent.add((typeId, value));
    if (typeId == 2) _cvAbsent = value;
  }

  @override
  Future<void> removeFile(int fileId) async {
    removed.add(fileId);
    _fotoFiles = false;
  }
}

/// Berkas pribadi di MATRIX: kelengkapan, tidak memiliki, hapus berkas.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('kelengkapan, tandai tidak memiliki, hapus berkas', (
    tester,
  ) async {
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DocumentsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('33%'), findsOneWidget);
    expect(find.text('Berkas belum lengkap'), findsOneWidget);
    expect(find.text('1 berkas'), findsOneWidget);
    expect(find.text('Belum diisi'), findsNWidgets(2));

    // Jenis tidak wajib: centang "tidak memiliki".
    await tester.tap(find.text('Curriculum Vitae (CV)'));
    await tester.pumpAndSettle();
    expect(find.text('Saya tidak memiliki berkas ini'), findsOneWidget);
    await tester.tap(find.text('Saya tidak memiliki berkas ini'));
    await tester.pumpAndSettle();
    expect(repo.absent, [(2, true)]);
    expect(
      find.text('Ditandai: Anda tidak memiliki berkas ini.'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('66%'), findsOneWidget);
    expect(find.text('Tidak memiliki'), findsOneWidget);

    // Jenis wajib: tidak ada pilihan "tidak memiliki"; hapus berkas.
    await tester.tap(find.text('Pas foto'));
    await tester.pumpAndSettle();
    expect(find.text('Saya tidak memiliki berkas ini'), findsNothing);
    expect(find.text('Ganti berkas dari'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus foto.jpg'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(repo.removed, [10]);
    expect(find.text('Unggah dari'), findsOneWidget);
  });
}
