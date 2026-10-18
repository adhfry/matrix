import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/security_service.dart';
import '../widgets/custom_pin_keyboard.dart';

class PinSetupPage extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const PinSetupPage({super.key, required this.onSuccess});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isError = false;
  String _errorMessage = '';

  void _onNumberPressed(String number) {
    if (_isConfirming) {
      if (_confirmPin.length < 6) {
        setState(() {
          _confirmPin += number;
          _isError = false;
        });

        if (_confirmPin.length == 6) {
          _verifyPins();
        }
      }
    } else {
      if (_pin.length < 6) {
        setState(() {
          _pin += number;
          _isError = false;
        });

        if (_pin.length == 6) {
          setState(() => _isConfirming = true);
        }
      }
    }
  }

  void _onBackspace() {
    if (_isConfirming) {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          _isError = false;
        });
      }
    } else {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _isError = false;
        });
      }
    }
  }

  Future<void> _verifyPins() async {
    if (_pin == _confirmPin) {
      final security = ref.read(securityServiceProvider);
      await security.setPin(_pin);

      if (mounted) {
        _showSuccessDialog();
      }
    } else {
      setState(() {
        _isError = true;
        _errorMessage = 'PIN tidak cocok';
        _confirmPin = '';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 12),
            const Text('PIN Berhasil Dibuat'),
          ],
        ),
        content: const Text(
          'PIN Anda telah berhasil dibuat. Gunakan PIN ini untuk masuk ke aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _askForBiometric();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _askForBiometric() async {
    final security = ref.read(securityServiceProvider);
    final isAvailable = await security.isBiometricAvailable();

    if (!isAvailable || !mounted) {
      widget.onSuccess();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan Biometrik?'),
        content: const Text(
          'Apakah Anda ingin mengaktifkan login dengan sidik jari atau wajah?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSuccess();
            },
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _setupBiometric();
            },
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupBiometric() async {
    final security = ref.read(securityServiceProvider);
    final success = await security.authenticateWithBiometric();

    if (success) {
      await security.setBiometricEnabled(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometrik berhasil diaktifkan'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buat PIN'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    kToolbarHeight,
            child: Column(
              children: [
                const Spacer(),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildPinDots(),
                if (_isError) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(),
                ] else
                  const SizedBox(height: 16),
                const Spacer(),
                CustomPinKeyboard(
                  onNumberPressed: _onNumberPressed,
                  onBackspace: _onBackspace,
                  showBiometric: false,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          _isConfirming ? Icons.check_circle_outline : Icons.pin_outlined,
          size: 64,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _isConfirming ? 'Konfirmasi PIN' : 'Buat PIN Baru',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _isConfirming ? 'Masukkan kembali PIN Anda' : 'Masukkan PIN 6 digit',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < currentPin.length
                ? (_isError ? AppColors.error : AppColors.primary)
                : AppColors.border,
          ),
        );
      }),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        _errorMessage,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}
