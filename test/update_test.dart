import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/update/data/update_repository.dart';
import 'package:matrix/features/update/ui/update_views.dart';

final _release = AppReleaseInfo.fromJson({
  'id': 3,
  'version_name': '2.1.0',
  'version_code': 3,
  'title': 'Surat izin otomatis & absen lebih cepat',
  'summary': 'Pembaruan rutin Oktober.',
  'changelog': [
    {
      'title': 'Baru',
      'items': [
        'Surat izin bertanda tangan otomatis',
        'Pembatalan izin per hari',
      ],
    },
    {
      'title': 'Perbaikan',
      'items': ['Kanvas tanda tangan tidak lagi ikut menggulir'],
    },
  ],
  'notes': 'Ukuran unduhan sekitar 48 MB, sebaiknya pakai Wi-Fi.',
  'is_mandatory': true,
  'release_date': '2026-10-22',
  'apk_size': 50331648,
  'apk_sha256': 'a' * 64,
  'download_url': 'https://contoh.test/apk',
  'skipped': [
    {'version_name': '2.0.5', 'title': 'Perbaikan absen malam'},
  ],
});

class _FakeInstaller extends AppInstaller {
  _FakeInstaller(this.initial);
  final InstallState initial;
  @override
  InstallState build() => initial;
}

class _FakeUpdate extends AppUpdateController {
  _FakeUpdate(this.value);
  final UpdateCheck? value;
  @override
  Future<UpdateCheck?> build() async => value;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [...overrides],
      child: MaterialApp(theme: AppTheme.light(), home: home),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'wajib: catatan rilis lengkap, tanpa "Nanti saja", tidak bisa kembali',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(UpdateGateScreen(release: _release)));
      expect(find.text('Pembaruan wajib'), findsOneWidget);
      expect(find.text('MATRIX 2.1.0'), findsOneWidget);
      expect(find.text('BARU'), findsOneWidget);
      expect(find.text('Pembatalan izin per hari'), findsOneWidget);
      expect(find.text('2.0.5: Perbaikan absen malam'), findsOneWidget);
      expect(find.text('Perbarui sekarang'), findsOneWidget);
      expect(find.text('Nanti saja'), findsNothing);

      final pop = tester.widget<PopScope>(find.byType(PopScope));
      expect(pop.canPop, isFalse);
    },
  );

  testWidgets('opsional: ada "Nanti saja"; unduhan menampilkan progres', (
    tester,
  ) async {
    _phone(tester);
    var later = false;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: UpdateActions(release: _release, onLater: () => later = true),
        ),
      ),
    );
    await tester.tap(find.text('Nanti saja'));
    expect(later, isTrue);

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: UpdateActions(release: _release, onLater: () {}),
        ),
        overrides: [
          appInstallerProvider.overrideWith(
            () => _FakeInstaller(
              const InstallState(
                InstallStage.downloading,
                received: 12 * 1024 * 1024,
                total: 48 * 1024 * 1024,
              ),
            ),
          ),
        ],
      ),
    );
    expect(find.text('Mengunduh 12,0 MB dari 48,0 MB'), findsOneWidget);
    expect(find.text('Batalkan unduhan'), findsOneWidget);
    expect(find.text('Nanti saja'), findsNothing);
  });

  testWidgets(
    'izin pasang belum diberikan: arahan jelas & tombol ke pengaturan',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(body: UpdateActions(release: _release)),
          overrides: [
            appInstallerProvider.overrideWith(
              () => _FakeInstaller(
                const InstallState(InstallStage.needsPermission),
              ),
            ),
          ],
        ),
      );
      expect(find.textContaining('Izinkan dari sumber ini'), findsOneWidget);
      expect(find.text('Buka pengaturan izin'), findsOneWidget);
    },
  );

  testWidgets('halaman pembaruan saat sudah terbaru', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        const UpdateScreen(),
        overrides: [
          appUpdateProvider.overrideWith(
            () => _FakeUpdate(
              const UpdateCheck(
                currentVersion: '2.1.0',
                currentBuild: 3,
                available: false,
                mandatory: false,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('MATRIX sudah versi terbaru'), findsOneWidget);
    expect(find.text('Versi 2.1.0 (build 3).'), findsOneWidget);
    expect(find.text('Periksa pembaruan'), findsOneWidget);
  });
}
