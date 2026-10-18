import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/services/security_service.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/pin_display.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/login_page.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  final Widget child;

  const PinLockScreen({super.key, required this.child});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with WidgetsBindingObserver {
  SecurityService get _securityService => ref.read(securityServiceProvider);
  final AuthRepository _authRepository = AuthRepository();

  bool _isLocked = true;
  bool _isLoading = true;
  bool _canUseBiometric = false;
  String _biometricTypeName = 'Biometrik';
  int _attemptCount = 0;
  String _currentPin = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // When app comes back from background
    if (state == AppLifecycleState.resumed) {
      // Check if activated but no PIN set -> logout
      await _checkPinRequirement();
    }

    // Lock app when it goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) {
        setState(() => _isLocked = true);
      }
    }
  }

  Future<void> _checkPinRequirement() async {
    final isActivated = await _authRepository.isActivated();
    final isLoggedIn = await _authRepository.isLoggedIn();
    final isPinSet = await _securityService.isPinSet();

    // If activated and logged in but no PIN set -> logout
    if (isActivated && isLoggedIn && !isPinSet) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    // Logout and redirect to login
    await _authRepository.logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );

      SnackBarHelper.showInfo(
        context,
        'Harap set PIN terlebih dahulu untuk keamanan',
      );
    }
  }

  Future<void> _checkLockStatus() async {
    final isPinSet = await _securityService.isPinSet();
    final isActivated = await _authRepository.isActivated();
    final isLoggedIn = await _authRepository.isLoggedIn();

    // If activated and logged in but no PIN -> logout
    if (isActivated && isLoggedIn && !isPinSet) {
      setState(() => _isLoading = false);
      await _performLogout();
      return;
    }

    final isBiometricEnabled = await _securityService.isBiometricEnabled();
    final canUseBiometric = await _securityService.canUseBiometric();
    final biometricTypeName = await _securityService.getBiometricTypeName();

    setState(() {
      _isLocked = isPinSet;
      _isLoading = false;
      _canUseBiometric = canUseBiometric && isBiometricEnabled;
      _biometricTypeName = biometricTypeName;
    });

    // Auto show biometric if enabled
    if (_isLocked && _canUseBiometric) {
      await Future.delayed(const Duration(milliseconds: 500));
      _handleBiometricAuth();
    }
  }

  void _onNumberPressed(String number) {
    if (_currentPin.length < 6) {
      setState(() {
        _currentPin += number;
        _hasError = false;
      });

      // Auto submit when 6 digits
      if (_currentPin.length == 6) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _handlePinSubmit(_currentPin);
        });
      }
    }
  }

  void _onBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _handlePinSubmit(String pin) async {
    final isValid = await _securityService.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      // PIN correct - unlock
      setState(() {
        _isLocked = false;
        _attemptCount = 0;
      });
    } else {
      // PIN incorrect
      _attemptCount++;

      setState(() {
        _currentPin = '';
        _hasError = true;
      });

      if (_attemptCount >= 5) {
        // Too many attempts - logout
        SnackBarHelper.showError(
          context,
          'Terlalu banyak percobaan gagal. Silakan login kembali',
        );

        await Future.delayed(const Duration(seconds: 1));
        await _performLogout();
      } else {
        SnackBarHelper.showError(
          context,
          'PIN salah. ${5 - _attemptCount} percobaan tersisa',
        );

        // Reset error state
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          setState(() => _hasError = false);
        }
      }
    }
  }

  Future<void> _handleBiometricAuth() async {
    final authenticated = await _securityService.authenticateWithBiometric();

    if (authenticated && mounted) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isLocked) {
      return widget.child;
    }

    // Show lock screen with custom keypad
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // App Logo/Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldGreen.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Masukkan PIN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'Masukkan PIN untuk membuka MATRIX Mobile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // PIN Display
                    PinDisplay(
                      pinLength: 6,
                      currentLength: _currentPin.length,
                      hasError: _hasError,
                    ),

                    const SizedBox(height: 32),

                    // Biometric Button (if available)
                    if (_canUseBiometric)
                      Column(
                        children: [
                          TextButton.icon(
                            onPressed: _handleBiometricAuth,
                            icon: Icon(
                              _biometricTypeName == 'Face ID'
                                  ? Icons.face
                                  : Icons.fingerprint,
                              color: AppColors.emeraldGreen,
                            ),
                            label: Text(
                              'Gunakan $_biometricTypeName',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.emeraldGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Attempts warning
                    if (_attemptCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${5 - _attemptCount} percobaan tersisa',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Custom Numeric Keypad
            CustomNumericKeypad(
              onNumberPressed: _onNumberPressed,
              onBackspace: _onBackspace,
              showBiometric: _canUseBiometric,
              onBiometric: _canUseBiometric ? _handleBiometricAuth : null,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
