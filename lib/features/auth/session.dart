import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../security/pin_service.dart';
import 'data/auth_repository.dart';

/// Keadaan sesi menentukan layar akar aplikasi.
sealed class SessionState {
  const SessionState();
}

class SessionBooting extends SessionState {
  const SessionBooting();
}

/// Perangkat belum pernah diaktivasi: alur email -> kode.
class SessionNeedsActivation extends SessionState {
  const SessionNeedsActivation();
}

class SessionNeedsLogin extends SessionState {
  const SessionNeedsLogin({this.lastUsername, this.notice});
  final String? lastUsername;

  /// Alasan diarahkan ke login (mis. sesi berakhir), ditampilkan sekali.
  final String? notice;
}

class SessionLocked extends SessionState {
  const SessionLocked(this.user, {required this.biometric});
  final AppUser user;
  final bool biometric;
}

class SessionReady extends SessionState {
  const SessionReady(this.user, {this.offerPin = false});
  final AppUser user;

  /// Baru login dengan password & belum punya PIN: tawarkan membuat PIN.
  final bool offerPin;
}

class SessionController extends Notifier<SessionState>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _unauthSub;
  DateTime? _pausedAt;

  /// Aplikasi di latar belakang lebih lama dari ini -> kunci PIN lagi.
  static const relockAfter = Duration(minutes: 5);

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  PinService get _pin => ref.read(pinServiceProvider);

  @override
  SessionState build() {
    WidgetsBinding.instance.addObserver(this);
    _unauthSub = ref
        .read(apiClientProvider)
        .onUnauthorized
        .listen((_) => _expire());
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _unauthSub?.cancel();
    });
    Future.microtask(_boot);
    return const SessionBooting();
  }

  Future<void> _boot() async {
    if (!await _auth.hasToken()) {
      state = await _auth.isActivated()
          ? SessionNeedsLogin(lastUsername: await _auth.lastUsername())
          : const SessionNeedsActivation();
      return;
    }
    final user = await _auth.cachedUser();
    if (user == null) {
      state = SessionNeedsLogin(lastUsername: await _auth.lastUsername());
      return;
    }
    if (await _pin.isSet()) {
      state = SessionLocked(user, biometric: await _pin.biometricEnabled());
    } else {
      // Tanpa PIN, sesi tidak diingat: wajib password tiap membuka aplikasi (perilaku v1).
      await _auth.logout();
      state = SessionNeedsLogin(lastUsername: await _auth.lastUsername());
    }
  }

  void loggedIn(AppUser user) => state = SessionReady(user, offerPin: true);

  /// PIN/biometrik hanya membuka kunci di HP; token tetap diperiksa ke server.
  /// Bila server menolak (token dicabut/login di HP lain), interceptor 401
  /// memicu [_expire] sehingga pegawai langsung diarahkan ke login dengan
  /// pesan jelas (bug v1: tetap di dalam aplikasi lalu semua data "unauthenticated").
  ///
  /// Beranda baru dibuka SETELAH server menerima token. 401 -> [_expire] ke login,
  /// pegawai tidak pernah sempat masuk fitur. Tanpa jaringan -> pakai data tersimpan.
  Future<void> unlocked() async {
    final s = state;
    if (s is! SessionLocked) return;
    try {
      final fresh = await _auth.refreshProfile().timeout(
        const Duration(seconds: 10),
      );
      if (state is SessionLocked) state = SessionReady(fresh);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        if (state is SessionLocked) {
          await logout(notice: 'Sesi Anda berakhir. Silakan masuk lagi.');
        }
        return;
      }
      if (state is SessionLocked) state = SessionReady(s.user);
    } on TimeoutException {
      if (state is SessionLocked) state = SessionReady(s.user);
    }
  }

  void pinOfferHandled() {
    final s = state;
    if (s is SessionReady) state = SessionReady(s.user);
  }

  void userUpdated(AppUser user) {
    if (state is SessionReady) state = SessionReady(user);
  }

  Future<void> logout({String? notice}) async {
    await _auth.logout();
    state = SessionNeedsLogin(
      lastUsername: await _auth.lastUsername(),
      notice: notice,
    );
  }

  Future<void> _expire() async {
    if (state is SessionNeedsLogin || state is SessionNeedsActivation) return;
    await logout(notice: 'Sesi Anda berakhir. Silakan masuk lagi.');
  }

  @override
  // `state` sudah dipakai Notifier, jadi parameter diberi nama lain.
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (lifecycle == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      final current = state;
      if (current is SessionReady && away > relockAfter) {
        _pin.isSet().then((has) async {
          if (has && state is SessionReady) {
            state = SessionLocked(
              current.user,
              biometric: await _pin.biometricEnabled(),
            );
          }
        });
      }
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Pegawai yang sedang masuk. Hanya dipakai di layar setelah [SessionReady].
final currentUserProvider = Provider<AppUser>((ref) {
  final s = ref.watch(sessionProvider);
  return switch (s) {
    SessionReady(:final user) => user,
    SessionLocked(:final user) => user,
    _ => throw StateError('Belum ada pegawai yang masuk'),
  };
});
