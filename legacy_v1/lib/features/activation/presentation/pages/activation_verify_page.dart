import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class ActivationVerifyPage extends StatefulWidget {
  const ActivationVerifyPage({super.key, required this.email});

  final String email;

  @override
  State<ActivationVerifyPage> createState() => _ActivationVerifyPageState();
}

class _ActivationVerifyPageState extends State<ActivationVerifyPage> {
  final _authRepository = AuthRepository();
  bool _isLoading = false;
  final _pinController = TextEditingController();
  
  // Timer untuk resend
  int _remainingSeconds = 300; // 5 minutes
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
        
        // Enable resend after 1 minute
        if (_remainingSeconds <= 240 && !_canResend) {
          _canResend = true;
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isLoading) return;
    
    setState(() {
      _isLoading = true;
      _canResend = false;
    });

    try {
      final response = await _authRepository.requestActivation(widget.email);
      
      if (response.status == 'success' && mounted) {
        SnackBarHelper.showSuccess(context, 'Kode baru telah dikirim ke email Anda');
        
        // Reset timer
        setState(() {
          _remainingSeconds = 300;
        });
        
        // Cooldown 1 menit sebelum bisa resend lagi
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) {
            setState(() => _canResend = true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
        setState(() => _canResend = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode(String code) async {
    if (code.length != AppConstants.activationCodeLength) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authRepository.verifyActivation(
        email: widget.email,
        code: code,
      );

      if (response.status == 'success' && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );

        SnackBarHelper.showSuccess(context, response.message);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
        _pinController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
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
                'Masukkan Kode',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Kami telah mengirim kode 6 digit ke ${widget.email}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              // PIN Input
              Center(
                child: Pinput(
                  controller: _pinController,
                  length: AppConstants.activationCodeLength,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration?.copyWith(
                      border: Border.all(
                        color: AppColors.emeraldGreen,
                        width: 2,
                      ),
                    ),
                  ),
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration?.copyWith(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.emeraldGreen),
                    ),
                  ),
                  errorPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration?.copyWith(
                      border: Border.all(color: AppColors.error),
                    ),
                  ),
                  onCompleted: _isLoading ? null : _verifyCode,
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(height: 24),
              
              // Timer
              if (_remainingSeconds > 0)
                Text(
                  'Kode berlaku: ${_formatTime(_remainingSeconds)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _remainingSeconds < 60 
                        ? AppColors.error 
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const Text(
                  'Kode sudah kadaluarsa',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Resend Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Tidak menerima kode? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_canResend && !_isLoading)
                    TextButton(
                      onPressed: _resendCode,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Kirim Ulang',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.emeraldGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      _isLoading 
                          ? 'Mengirim...' 
                          : 'Tunggu ${60 - (300 - _remainingSeconds)}s',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

