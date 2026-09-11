import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/services/security_service.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/pin_display.dart';

class VerifyPinPage extends ConsumerStatefulWidget {
  final String title;
  final String description;
  
  const VerifyPinPage({
    super.key,
    this.title = 'Masukkan PIN',
    this.description = 'Masukkan PIN Anda untuk melanjutkan',
  });

  @override
  ConsumerState<VerifyPinPage> createState() => _VerifyPinPageState();
}

class _VerifyPinPageState extends ConsumerState<VerifyPinPage> {
  SecurityService get _securityService => ref.read(securityServiceProvider);
  String _currentPin = '';
  bool _isLoading = false;
  bool _hasError = false;
  int _attemptCount = 0;

  @override
  void dispose() {
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_currentPin.length < 6 && !_isLoading) {
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
    if (_currentPin.isNotEmpty && !_isLoading) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _handlePinSubmit(String pin) async {
    setState(() => _isLoading = true);
    
    final isValid = await _securityService.verifyPin(pin);
    
    if (!mounted) return;
    
    if (isValid) {
      // PIN correct
      Navigator.pop(context, true);
    } else {
      // PIN incorrect
      _attemptCount++;
      
      setState(() {
        _currentPin = '';
        _hasError = true;
        _isLoading = false;
      });
      
      if (_attemptCount >= 3) {
        // Too many attempts
        SnackBarHelper.showError(
          context,
          'Terlalu banyak percobaan gagal',
        );
        Navigator.pop(context, false);
      } else {
        SnackBarHelper.showError(
          context,
          'PIN salah. \ percobaan tersisa',
        );
        
        // Reset error state
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          setState(() => _hasError = false);
        }
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
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
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
                      widget.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    Text(
                      widget.description,
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
                    
                    const SizedBox(height: 32),
                    
                    // Forgot PIN
                    TextButton(
                      onPressed: () {
                        SnackBarHelper.showInfo(
                          context,
                          'Hubungi administrator untuk reset PIN',
                        );
                      },
                      child: const Text(
                        'Lupa PIN?',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.emeraldGreen,
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
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
