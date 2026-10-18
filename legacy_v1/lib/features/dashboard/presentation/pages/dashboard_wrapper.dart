import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/security_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../security/presentation/pages/pin_entry_page.dart';
import 'dashboard_page.dart';

/// Wrapper untuk dashboard yang mengecek autentikasi PIN/Biometrik
/// Jika tidak ada PIN yang di-set, user harus login dengan username/password
class DashboardWrapper extends ConsumerStatefulWidget {
  const DashboardWrapper({super.key});

  @override
  ConsumerState<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends ConsumerState<DashboardWrapper> {
  bool _isLoading = true;
  bool _hasPinSetup = false;

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
  }

  Future<void> _checkPinSetup() async {
    final securityService = ref.read(securityServiceProvider);
    final hasPIN = await securityService.isPinSet();

    if (mounted) {
      setState(() {
        _hasPinSetup = hasPIN;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Jika tidak ada PIN, arahkan ke login page
    if (!_hasPinSetup) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Jika ada PIN, tampilkan PIN entry
    return FutureBuilder<bool>(
      future: ref.read(securityServiceProvider).isBiometricEnabled(),
      builder: (context, snapshot) {
        final canUseBiometric = snapshot.data ?? false;

        return PinEntryPage(
          canUseBiometric: canUseBiometric,
        );
      },
    );
  }
}
