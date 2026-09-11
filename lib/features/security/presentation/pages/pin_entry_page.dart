import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/security_service.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../widgets/custom_pin_keyboard.dart';

class PinEntryPage extends ConsumerStatefulWidget {
  final bool canUseBiometric;

  const PinEntryPage({
    super.key,
    this.canUseBiometric = false,
  });

  @override
  ConsumerState<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends ConsumerState<PinEntryPage> {
  String _pin = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric jika tersedia
    if (widget.canUseBiometric) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _tryBiometric();
      });
    }
  }

  Future<void> _tryBiometric() async {
    final security = ref.read(securityServiceProvider);
    final isEnabled = await security.isBiometricEnabled();

    if (isEnabled && mounted) {
      final success = await security.authenticateWithBiometric();
      if (success && mounted) {
        // Biometric berhasil, navigate ke dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DashboardPage(),
          ),
        );
      }
    }
  }

  void _onNumberPressed(String number) {
    if (_pin.length < 6) {
      setState(() {
        _pin += number;
        _isError = false;
      });

      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final security = ref.read(securityServiceProvider);
    final isValid = await security.verifyPin(_pin);

    if (mounted) {
      if (isValid) {
        // PIN benar, navigate ke dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DashboardPage(),
          ),
        );
      } else {
        setState(() {
          _isError = true;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildPinDotsWithBiometric(),
                      if (_isError) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(),
                      ] else
                        const SizedBox(height: 16),
                      const Spacer(),
                      CustomPinKeyboard(
                        onNumberPressed: _onNumberPressed,
                        onBackspace: _onBackspace,
                        onBiometric: widget.canUseBiometric
                            ? _tryBiometric
                            : null,
                        showBiometric: widget.canUseBiometric,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          'Masukkan PIN',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan PIN 6 digit Anda',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _pin.length
                ? (_isError ? AppColors.error : AppColors.primary)
                : AppColors.border,
          ),
        );
      }),
    );
  }

  Widget _buildPinDotsWithBiometric() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // PIN Dots
        ...(List.generate(6, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < _pin.length
                  ? (_isError ? AppColors.error : AppColors.primary)
                  : AppColors.border,
            ),
          );
        })),

        // Biometric button jika tersedia
        // if (widget.canUseBiometric) ...[
        //   const SizedBox(width: 16),
        //   Material(
        //     color: Colors.transparent,
        //     child: InkWell(
        //       onTap: _tryBiometric,
        //       borderRadius: BorderRadius.circular(20),
        //       child: Container(
        //         padding: const EdgeInsets.all(8),
        //         decoration: BoxDecoration(
        //           color: AppColors.primary.withValues(alpha: 0.1),
        //           borderRadius: BorderRadius.circular(20),
        //         ),
        //         child: Icon(
        //           Icons.fingerprint,
        //           color: AppColors.primary,
        //           size: 24,
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'PIN salah. Silakan coba lagi.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}
