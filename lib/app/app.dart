import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/push_service.dart';
import '../core/storage/secure_store.dart';
import '../features/calls/call_controller.dart';
import '../features/auth/session.dart';
import '../core/widgets/matrix_mark.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/matrix_splash.dart';
import '../features/auth/ui/activation_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/security/ui/pin_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/update/data/update_repository.dart';
import '../features/update/ui/update_views.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(() async {
      final saved = await ref.read(secureStoreProvider).themeMode();
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    });
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(secureStoreProvider).saveThemeMode(mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Navigator akar: saat sesi berakhir/terkunci semua layar & dialog yang
/// terbuka ditutup, jadi pegawai tidak tertinggal di layar yang butuh sesi.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class MatrixApp extends ConsumerWidget {
  const MatrixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (prev is SessionReady && next is! SessionReady) {
        rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
        // Panggilan tetap berjalan saat aplikasi terkunci; tampilkan lagi layarnya.
        if (next is SessionLocked) ref.read(callControllerProvider.notifier).showScreen();
      }
      // Dibuka dari notifikasi panggilan: angkat/tolak tanpa menunggu PIN.
      if (prev is SessionBooting && (next is SessionLocked || next is SessionReady)) {
        ref.read(pushServiceProvider).openLaunchCall();
      }
    });
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'MATRIX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        // Batasi skala huruf di 130% (DESIGN.md §10) supaya tata letak tetap utuh.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        );
      },
      home: const _SessionRoot(),
    );
  }
}

/// Layar akar mengikuti [SessionState]; pergantian memakai fade-through.
class _SessionRoot extends ConsumerWidget {
  const _SessionRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final onboarded = ref.watch(onboardedProvider).value;
    final splashDone = ref.watch(splashDoneProvider);
    final firstRun = s is SessionNeedsActivation || s is SessionNeedsLogin;
    // Pembaruan wajib menahan seluruh aplikasi (juga sebelum login).
    final update = ref.watch(appUpdateProvider).value;
    final gate = update != null && update.mandatory ? update.latest : null;
    final Widget screen = switch (s) {
      _ when !splashDone => const MatrixSplash(),
      _ when gate != null => UpdateGateScreen(release: gate),
      _ when firstRun && onboarded == null => const _BootScreen(),
      _ when firstRun && onboarded == false => const OnboardingScreen(),
      SessionBooting() => const _BootScreen(),
      SessionNeedsActivation() => const ActivationScreen(),
      SessionNeedsLogin(:final lastUsername, :final notice) => LoginScreen(
        lastUsername: lastUsername,
        notice: notice,
      ),
      SessionLocked(:final user, :final biometric, :final hasPin) =>
        PinScreen.unlock(user: user, biometric: biometric, hasPin: hasPin),
      SessionReady() => const HomeShell(),
    };
    return PageTransitionSwitcher(
      duration: Motion.of(context, Motion.emphasis),
      transitionBuilder: (child, a, b) => FadeThroughTransition(
        animation: a,
        secondaryAnimation: b,
        fillColor: context.mx.canvas,
        child: child,
      ),
      // Splash punya key tetap: status sesi yang berganti di belakangnya
      // (Booting -> Locked) tidak boleh membuat ulang animasi & bunyinya.
      child: KeyedSubtree(
        key: ValueKey(
          !splashDone
              ? MatrixSplash
              : gate != null
              ? UpdateGateScreen
              : s.runtimeType,
        ),
        child: screen,
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Memuat MATRIX',
          child: const MatrixMark(size: 96),
        ),
      ),
    );
  }
}
