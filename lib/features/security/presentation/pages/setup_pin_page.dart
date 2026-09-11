import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/services/security_service.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/pin_display.dart';

class SetupPinPage extends ConsumerStatefulWidget {
  const SetupPinPage({super.key});

  @override
  ConsumerState<SetupPinPage> createState() => _SetupPinPageState();
}

class _SetupPinPageState extends ConsumerState<SetupPinPage> {
  SecurityService get _securityService => ref.read(securityServiceProvider);
  
  bool _isFirstStep = true;
  String _firstPin = '';
  String _currentPin = '';
  bool _hasError = false;

  @override
  void dispose() {
    super.dispose();
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
    if (_isFirstStep) {
      // Step 1: Save first PIN
      setState(() {
        _firstPin = pin;
        _isFirstStep = false;
        _currentPin = '';
      });
    } else {
      // Step 2: Confirm PIN
      if (pin == _firstPin) {
        // Save PIN
        await _securityService.setPin(pin);
        
        if (!mounted) return;
        
        // Show success and navigate back
        SnackBarHelper.showSuccess(context, 'PIN berhasil dibuat');
        
        Navigator.pop(context, true);
      } else {
        // PIN doesn't match
        setState(() {
          _hasError = true;
          _currentPin = '';
        });
        
        SnackBarHelper.showError(context, 'PIN tidak sama. Silakan coba lagi');
        
        // Reset to first step after delay
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        
        setState(() {
          _isFirstStep = true;
          _firstPin = '';
          _hasError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      _isFirstStep ? 'Buat PIN Anda' : 'Konfirmasi PIN',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    Text(
                      _isFirstStep
                          ? 'Buat PIN 6 digit untuk mengamankan aplikasi Anda'
                          : 'Masukkan kembali PIN untuk konfirmasi',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                    
                    const SizedBox(height: 24),
                    
                    // Step Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepIndicator(1, !_isFirstStep),
                        const SizedBox(width: 8),
                        _buildStepIndicator(2, false),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'PIN digunakan untuk mengamankan aplikasi. Jangan bagikan PIN Anda kepada siapa pun.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.info,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isCompleted) {
    return Container(
      width: isCompleted ? 40 : 12,
      height: 12,
      decoration: BoxDecoration(
        gradient: isCompleted || step == (_isFirstStep ? 1 : 2)
            ? AppColors.primaryGradient
            : null,
        color: isCompleted || step == (_isFirstStep ? 1 : 2)
            ? null
            : AppColors.border,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
