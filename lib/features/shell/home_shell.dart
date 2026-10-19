import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/push/push_service.dart';
import '../../core/storage/secure_store.dart';
import '../../core/widgets/finance.dart';
import '../identity/data/identity_repository.dart';
import '../identity/ui/identity_screen.dart';
import '../account/ui/account_screen.dart';
import '../attendance/ui/attendance_launcher.dart';
import '../auth/session.dart';
import '../home/ui/home_screen.dart';
import '../kinerja/ui/kinerja_screen.dart';
import '../schedule/ui/schedule_screen.dart';
import '../security/ui/pin_screen.dart';

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
  static const kinerja = 2;
  static const account = 3;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Tab dibangun saat pertama dibuka lalu dipertahankan (data tidak dimuat ulang tiap pindah tab).
  final _built = <int>{Tabs.home};
  int _previous = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeOfferPin();
      await _maybePromptIdentity();
      await _maybeAskPush();
      await ref.read(pushServiceProvider).attach();
    });
  }

  /// Sekali per HP: jelaskan dulu manfaatnya, baru minta izin notifikasi Android.
  Future<void> _maybeAskPush() async {
    final push = ref.read(pushServiceProvider);
    final store = ref.read(secureStoreProvider);
    if (!mounted ||
        await store.pushAsked() ||
        await push.permission() != PushPermission.notDetermined) {
      return;
    }
    await store.setPushAsked();
    if (!mounted) return;
    final go = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(Icons.notifications_active_outlined, size: 52),
              const SizedBox(height: Sp.lg),
              Text('Aktifkan notifikasi', style: ctx.text.titleMedium),
              const SizedBox(height: Sp.sm),
              for (final line in const [
                'Pengingat saat jendela check-in & check-out dibuka',
                'Jadwal dan jaspel terbit, keputusan izin',
                'Pesan chat SiLAKES web langsung ke HP',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: ctx.mx.primary,
                      ),
                      const SizedBox(width: Sp.sm),
                      Expanded(child: Text(line, style: ctx.text.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: Sp.sm),
              Text(
                'Jenis notifikasi dan jam tenang bisa diatur kapan saja di Akun.',
                style: ctx.text.bodySmall?.copyWith(color: ctx.mx.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Aktifkan'),
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
    if (go == true) await push.requestPermission();
  }

  /// Sekali per hari: bila data diri belum 100%, minta dilengkapi.
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
    await store.setIdentityPromptDate(today);
    if (data.complete || !mounted) return;
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
                    value: data.completeness / 100,
                    size: 64,
                    stroke: 7,
                    center: Text(
                      '${data.completeness}%',
                      style: ctx.text.labelLarge?.copyWith(
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.lg),
                  Expanded(
                    child: Text(
                      'Lengkapi data diri Anda',
                      style: ctx.text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.md),
              Text(
                'Data kepegawaian harus lengkap dan sesuai KTP: ${data.missing.length} kolom belum diisi, termasuk ${data.missing.take(2).map((m) => m.split(': ').last).join(' dan ')}. Kolom yang memang tidak Anda miliki cukup dicentang "Tidak memiliki".',
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
    if (go == true && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<bool>(builder: (_) => const IdentityScreen()));
    }
  }

  Future<void> _maybeOfferPin() async {
    final s = ref.read(sessionProvider);
    if (s is! SessionReady || !s.offerPin || !mounted) return;
    ref.read(sessionProvider.notifier).pinOfferHandled();
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

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabProvider);
    _built.add(index);
    final forward = index >= _previous;
    _previous = index;

    const pages = [
      HomeScreen(),
      ScheduleScreen(),
      KinerjaScreen(),
      AccountScreen(),
    ];

    return PopScope(
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
          ],
        ),
        bottomNavigationBar: _NavBar(
          index: index,
          onSelect: (i) => ref.read(tabProvider.notifier).go(i),
          onAttend: () => launchAttendance(context, ref),
        ),
      ),
    );
  }
}

/// Navigasi bawah dengan tombol Absen bundar di tengah (DESIGN.md §11):
/// aksi paling sering selalu satu ketukan dari layar mana pun.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onSelect,
    required this.onAttend,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAttend;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget item(int i, IconData icon, IconData active, String label) =>
        Expanded(
          child: _NavItem(
            selected: index == i,
            icon: icon,
            activeIcon: active,
            label: label,
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
                  Tabs.kinerja,
                  Icons.bar_chart_rounded,
                  Icons.bar_chart_rounded,
                  'Kinerja',
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
          Positioned(
            top: 0,
            child: Semantics(
              button: true,
              label: 'Absen sekarang',
              excludeSemantics: true,
              child: PressScale(
                onTap: onAttend,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onAttend();
                  },
                  child: Column(
                    children: [
                      Container(
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
                        child: Icon(
                          Icons.camera_front_rounded,
                          color: c.onHero,
                          size: 28,
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
            ),
          ),
        ],
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
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
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
              child: Icon(
                selected ? activeIcon : icon,
                color: selected ? c.primary : c.inkMuted,
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
