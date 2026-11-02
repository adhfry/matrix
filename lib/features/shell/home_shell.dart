import '../sinta/ui/sinta_companion.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/push/push_service.dart';
import '../../core/storage/secure_store.dart';
import '../../core/widgets/finance.dart';
import '../../core/widgets/matrix_glyphs.dart';
import '../../core/widgets/mx.dart';
import '../identity/data/identity_repository.dart';
import '../identity/ui/identity_screen.dart';
import '../documents/data/document_repository.dart';
import '../documents/ui/documents_screen.dart';
import '../account/ui/account_screen.dart';
import '../attendance/ui/attendance_launcher.dart';
import '../scanner/ui/scan_camera_screen.dart';
import '../stock/ui/stock_scan_screen.dart';
import 'quick_camera_menu.dart';
import 'required_permissions.dart';
import '../auth/session.dart';
import '../calls/call_controller.dart';
import '../home/ui/home_screen.dart';
import '../chat/data/chat_repository.dart';
import '../chat/ui/chat_list_screen.dart';
import '../schedule/ui/schedule_screen.dart';
import '../security/pin_service.dart';
import '../security/ui/pin_screen.dart';
import '../update/data/update_repository.dart';
import '../update/ui/update_views.dart';

/// Tab aktif bisa diubah dari layar lain (mis. kartu kinerja di Beranda).
class ShellTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

final tabProvider = NotifierProvider<ShellTab, int>(ShellTab.new);

abstract final class Tabs {
  static const home = 0;
  static const schedule = 1;
  static const chat = 2;
  static const account = 3;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  // Tab dibangun saat pertama dibuka lalu dipertahankan (data tidak dimuat ulang tiap pindah tab).
  final _built = <int>{Tabs.home};
  int _previous = 0;

  // Izin wajib (notifikasi, lokasi, kamera, mikrofon, baterai): selama ada
  // yang belum diberikan, layar Izin wajib menutup aplikasi.
  Map<ReqPerm, PermState>? _perms;
  ReqPerm? _permBusy;
  final _permsReady = Completer<void>();

  bool get _permsMissing =>
      _perms != null && _perms!.values.any((s) => !s.granted);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(pushServiceProvider).attach();
      // Telepon yang sedang berdering tetap bisa diangkat walau izin belum lengkap.
      await ref.read(callControllerProvider.notifier).checkIncoming();
      await _refreshPerms();
      await _permsReady.future;
      if (!mounted) return;
      await _maybeOfferPin();
      await _maybePromptIdentity();
      _warmGps();
      await _maybeOfferUpdate();
    });
  }

  /// Pembaruan opsional: unduh otomatis saat Wi-Fi + lembar besar sekali sehari
  /// per versi. APK lama yang sudah terpasang dibersihkan dari cache.
  Future<void> _maybeOfferUpdate() async {
    final check = await ref.read(appUpdateProvider.future);
    if (check != null) unawaited(AppInstaller.cleanup(check.currentBuild));
    unawaited(autoDownloadUpdate(ref));
    if (mounted) await maybePromptUpdate(context, ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari Pengaturan Android: periksa ulang izin.
    if (state == AppLifecycleState.resumed) unawaited(_refreshPerms());
  }

  Future<void> _refreshPerms() async {
    final perms = ref.read(requiredPermissionsProvider);
    final now = await perms.check();
    if (!mounted) return;
    setState(() => _perms = now);
    unawaited(
      ref.read(pushServiceProvider).reportPermissions(
        RequiredPermissions.report(now),
      ),
    );
    if (!_permsMissing && !_permsReady.isCompleted) {
      // Notifikasi baru saja diizinkan: pastikan HP terdaftar untuk push & telepon.
      await ref.read(pushServiceProvider).requestPermission();
      _permsReady.complete();
    }
  }

  Future<void> _askPerm(ReqPerm p) async {
    final now = _perms?[p];
    if (now == null || _permBusy != null) return;
    setState(() => _permBusy = p);
    try {
      await ref.read(requiredPermissionsProvider).request(p, now);
    } finally {
      if (mounted) setState(() => _permBusy = null);
    }
    await _refreshPerms();
  }

  /// Diminta berurutan: dua dialog Android sekaligus membuat yang kedua hilang.
  Future<void> _askAllPerms() async {
    for (final p in ReqPerm.values) {
      final now = _perms?[p];
      if (now == null || now.granted) continue;
      await _askPerm(p);
      if (!mounted) return;
      // Dibawa ke Pengaturan: berhenti di sini, sisanya setelah kembali.
      if (now.blocked) return;
    }
  }

  /// Panaskan GPS saat aplikasi dibuka supaya posisi di layar absen cepat
  /// terkunci. Tidak meminta izin; diam bila izin/GPS belum ada.
  void _warmGps() {
    unawaited(() async {
      try {
        final p = await Geolocator.checkPermission();
        if (p != LocationPermission.always &&
            p != LocationPermission.whileInUse) {
          return;
        }
        if (!await Geolocator.isLocationServiceEnabled()) return;
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        // Hanya pemanasan; layar absen tetap mencari posisi sendiri.
      }
    }());
  }

  /// Sekali per hari: bila data diri belum 100%, minta dilengkapi; bila sudah,
  /// gantian berkas pribadi yang belum lengkap.
  Future<void> _maybePromptIdentity() async {
    final store = ref.read(secureStoreProvider);
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (await store.identityPromptDate() == today || !mounted) return;
    IdentityData data;
    try {
      data = await ref.read(identityRepositoryProvider).get();
    } on ApiException {
      return; // coba lagi saat aplikasi dibuka berikutnya
    }
    if (!data.complete) {
      await store.setIdentityPromptDate(today);
      if (!mounted) return;
      final go = await _completionSheet(
        percent: data.completeness,
        title: 'Lengkapi data diri Anda',
        message:
            'Data kepegawaian harus lengkap dan sesuai KTP: ${data.missing.length} kolom belum diisi, termasuk ${data.missing.take(2).map((m) => m.split(': ').last).join(' dan ')}. Kolom yang memang tidak Anda miliki cukup dicentang "Tidak memiliki".',
      );
      if (go && mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<bool>(builder: (_) => const IdentityScreen()));
      }
      return;
    }

    DocOverview docs;
    try {
      docs = await ref.read(documentRepositoryProvider).overview();
    } on ApiException {
      return;
    }
    await store.setIdentityPromptDate(today);
    if (docs.complete || !mounted) return;
    final go = await _completionSheet(
      percent: docs.percent,
      title: 'Lengkapi berkas pribadi',
      message:
          '${docs.total - docs.done} jenis berkas belum diisi, mis. ijazah, SK, atau SIP. Unggah dari kamera, galeri, atau PDF; yang memang tidak Anda punya cukup ditandai "Tidak memiliki".',
    );
    if (go && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()));
    }
  }

  Future<bool> _completionSheet({
    required int percent,
    required String title,
    required String message,
  }) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RingProgress(
                    value: percent / 100,
                    size: 64,
                    stroke: 7,
                    center: Text(
                      '$percent%',
                      style: ctx.text.labelLarge?.copyWith(
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.lg),
                  Expanded(child: Text(title, style: ctx.text.titleMedium)),
                ],
              ),
              const SizedBox(height: Sp.md),
              Text(
                message,
                style: ctx.text.bodyMedium?.copyWith(color: ctx.mx.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Lengkapi sekarang'),
                ),
              ),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Ingatkan besok'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return go == true;
  }

  Future<void> _maybeOfferPin() async {
    final s = ref.read(sessionProvider);
    if (s is! SessionReady || !s.offerPin || !mounted) return;
    ref.read(sessionProvider.notifier).pinOfferHandled();
    final pin = ref.read(pinServiceProvider);
    if (await pin.hasLock() || !mounted) return;
    if (await pin.biometricAvailable()) {
      await _offerBiometric(pin);
      return;
    }
    if (!mounted) return;
    final create = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(Icons.lock_outline_rounded, size: 52),
              const SizedBox(height: Sp.lg),
              Text(
                'Buat PIN supaya tidak perlu login lagi',
                style: ctx.text.titleMedium,
              ),
              const SizedBox(height: Sp.sm),
              Text(
                'Tanpa PIN, Anda harus memasukkan username dan password setiap membuka MATRIX. Dengan PIN 6 digit (dan sidik jari bila ada), cukup buka kunci.',
                style: ctx.text.bodyMedium?.copyWith(color: ctx.mx.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Buat PIN'),
                ),
              ),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Nanti saja'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (create == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => PinScreen.create(user: ref.read(currentUserProvider)),
          fullscreenDialog: true,
        ),
      );
    }
  }

  /// Satu ketuk: sidik jari/wajah membuka MATRIX, cadangannya PIN/pola HP.
  /// PIN aplikasi hanya pilihan, bukan syarat.
  Future<void> _offerBiometric(PinService pin) async {
    final name = await pin.biometricName();
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                name == 'wajah'
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
                size: 52,
              ),
              const SizedBox(height: Sp.lg),
              Text(
                'Masuk berikutnya dengan $name',
                style: ctx.text.titleMedium,
              ),
              const SizedBox(height: Sp.sm),
              Text(
                'Setelah tidak digunakan selama 5 menit, MATRIX terkunci dan meminta $name kembali. Bila sensor tidak terbaca, gunakan PIN atau pola kunci HP.',
                style: ctx.text.bodyMedium?.copyWith(color: ctx.mx.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'bio'),
                  icon: Icon(
                    name == 'wajah'
                        ? Icons.face_rounded
                        : Icons.fingerprint_rounded,
                  ),
                  label: Text('Aktifkan $name'),
                ),
              ),
              const SizedBox(height: Sp.sm),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, 'pin'),
                      child: const Text('Gunakan PIN aplikasi'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Nanti saja'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'bio') {
      if (await pin.authenticate()) {
        await pin.setBiometricEnabled(true);
        HapticFeedback.mediumImpact();
        if (mounted) {
          showMxSnack(context, 'Buka dengan $name aktif.', tone: Tone.ok);
        }
      } else if (mounted) {
        showMxSnack(
          context,
          'Belum aktif. Bisa diaktifkan kapan saja di Akun > Keamanan.',
          tone: Tone.pending,
        );
      }
    } else if (choice == 'pin') {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => PinScreen.create(user: ref.read(currentUserProvider)),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabProvider);
    _built.add(index);
    final forward = index >= _previous;
    _previous = index;

    const pages = [
      HomeScreen(),
      ScheduleScreen(),
      ChatListScreen(inTab: true),
      AccountScreen(),
    ];

    final shell = PopScope(
      canPop: index == Tabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(tabProvider.notifier).go(Tabs.home);
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            for (var i = 0; i < pages.length; i++)
              if (_built.contains(i))
                Offstage(
                  offstage: i != index,
                  child: TickerMode(
                    enabled: i == index,
                    child: i == index
                        ? TweenAnimationBuilder<double>(
                            key: ValueKey('tab-$i-$index'),
                            tween: Tween(begin: 0, end: 1),
                            duration: Motion.of(context, Motion.standard),
                            curve: Motion.curve,
                            builder: (context, t, child) => Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(
                                  (1 - t) * (forward ? 24 : -24),
                                  0,
                                ),
                                child: child,
                              ),
                            ),
                            child: pages[i],
                          )
                        : pages[i],
                  ),
                ),
            // SINTA menempel di tepi kiri/kanan, di atas semua tab.
            const Positioned.fill(child: SintaCompanion()),
          ],
        ),
        bottomNavigationBar: _NavBar(
          index: index,
          onSelect: (i) => ref.read(tabProvider.notifier).go(i),
          onAttend: () => launchAttendance(context, ref),
        ),
      ),
    );
    if (!_permsMissing) return shell;
    return Stack(
      children: [
        shell,
        Positioned.fill(
          child: PermissionGate(
            states: _perms!,
            busy: _permBusy,
            onRequest: _askPerm,
            onRequestAll: _askAllPerms,
            onLogout: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ),
      ],
    );
  }
}

/// Navigasi bawah dengan tombol Absen bundar di tengah (DESIGN.md §11):
/// aksi paling sering selalu satu ketukan dari layar mana pun.
class _NavBar extends ConsumerWidget {
  const _NavBar({
    required this.index,
    required this.onSelect,
    required this.onAttend,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAttend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(chatUnreadProvider);
    final c = context.mx;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget item(int i, IconData icon, IconData active, String label, {int badge = 0}) =>
        Expanded(
          child: _NavItem(
            selected: index == i,
            icon: icon,
            activeIcon: active,
            label: label,
            badge: badge,
            onTap: () => onSelect(i),
          ),
        );

    return SizedBox(
      height: 72 + bottom + 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 72 + bottom,
            padding: EdgeInsets.only(bottom: bottom),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.card),
              ),
              border: dark ? Border(top: BorderSide(color: c.line)) : null,
              boxShadow: dark
                  ? null
                  : [
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                item(
                  Tabs.home,
                  Icons.home_outlined,
                  Icons.home_rounded,
                  'Beranda',
                ),
                item(
                  Tabs.schedule,
                  Icons.calendar_month_outlined,
                  Icons.calendar_month_rounded,
                  'Jadwal',
                ),
                const SizedBox(width: 84),
                item(
                  Tabs.chat,
                  Icons.chat_bubble_outline_rounded,
                  Icons.chat_bubble_rounded,
                  'Chat',
                  badge: unread,
                ),
                item(
                  Tabs.account,
                  Icons.person_outline_rounded,
                  Icons.person_rounded,
                  'Akun',
                ),
              ],
            ),
          ),
          Positioned(top: 0, child: _AttendButton(onAttend: onAttend)),
        ],
      ),
    );
  }
}

/// Tombol Absen tengah. Ketuk = absen (seperti sebelumnya). Tahan = pintasan
/// tiga fitur kamera; geser jari ke salah satunya lalu lepas untuk membukanya
/// (aturan sentuhannya di [QuickMenuGesture]).
class _AttendButton extends ConsumerStatefulWidget {
  const _AttendButton({required this.onAttend});

  final VoidCallback onAttend;

  @override
  ConsumerState<_AttendButton> createState() => _AttendButtonState();
}

class _AttendButtonState extends ConsumerState<_AttendButton> {
  final _circle = GlobalKey();
  bool _down = false;

  /// Pusat lingkaran tombol (koordinat global) sebagai pusat menu.
  Offset _origin() {
    final box = _circle.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _attend() {
    HapticFeedback.mediumImpact();
    widget.onAttend();
  }

  Future<void> _open(QuickCameraAction picked) async {
    switch (picked) {
      case QuickCameraAction.attendance:
        widget.onAttend();
      case QuickCameraAction.stock:
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StockScanScreen()));
      case QuickCameraAction.ktp:
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScanCameraScreen()));
    }
  }

  /// Pembaca layar: menu dibuka tanpa seret dan dipilih dengan ketukan.
  Future<void> _openForScreenReader() async {
    final picked = await showQuickCameraMenu(context, origin: _origin());
    if (mounted && picked != null) await _open(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      button: true,
      label: 'Absen sekarang',
      onTap: widget.onAttend,
      onLongPressHint: 'buka pintasan kamera',
      onLongPress: _openForScreenReader,
      excludeSemantics: true,
      child: QuickMenuGesture(
        origin: _origin,
        onTap: _attend,
        onPicked: _open,
        onPressed: (v) => setState(() => _down = v),
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: Motion.of(context, const Duration(milliseconds: 120)),
          curve: Curves.easeOut,
          child: Column(
            children: [
              Container(
                key: _circle,
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.heroTop, c.heroBottom],
                  ),
                  border: Border.all(color: c.surface, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: c.heroBottom.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: MxGlyphIcon(
                    MxGlyph.absen,
                    color: c.onHero,
                    accent: c.onHero,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Absen',
                style: context.text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  /// Jumlah belum dibaca (tab Chat); 0 = tanpa lencana.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge pesan belum dibaca' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.standard),
              curve: Motion.curve,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: selected ? c.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: c.alert,
                child: Icon(
                  selected ? activeIcon : icon,
                  color: selected ? c.primary : c.inkMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: selected ? c.ink : c.inkMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
