import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/security_service.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../activation/presentation/pages/activation_welcome_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../security/presentation/pages/pin_entry_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _gradientController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _gradientOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // Gradient animation controller
    _gradientController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _gradientOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    // Step 1: Show logo on white background
    await _logoController.forward();

    // Wait a bit
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Fade in gradient
    await _gradientController.forward();

    // Wait a bit more
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 3: Check auth and navigate
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authRepository = AuthRepository();
    final securityService = ref.read(securityServiceProvider);
    
    final isLoggedIn = await authRepository.isLoggedIn();
    
    // Debug logging
    print('🔍 DEBUG - Splash Page:');
    print('   isLoggedIn: $isLoggedIn');

    if (!mounted) return;

    Widget nextPage;
    
    if (isLoggedIn) {
      // User sudah login, cek PIN
      final hasPIN = await securityService.isPinSet();
      
      // Debug logging
      print('   hasPIN: $hasPIN');
      
      if (hasPIN) {
        // Ada PIN, arahkan ke PIN Entry
        final canUseBiometric = await securityService.isBiometricEnabled();
        
        print('   canUseBiometric: $canUseBiometric');
        print('   → Navigate to: PIN ENTRY PAGE ✅');
        
        nextPage = PinEntryPage(
          canUseBiometric: canUseBiometric,
        );
      } else {
        print('   → Navigate to: LOGIN PAGE (No PIN)');
        // Tidak ada PIN, langsung ke dashboard (harus login dengan username/password setiap kali)
        nextPage = const LoginPage();
      }
    } else {
      print('   → Navigate to: LOGIN/ACTIVATION PAGE (Not logged in)');
      // Belum login, cek aktivasi
      final isActivated = await authRepository.isActivated();
      if (isActivated) {
        nextPage = const LoginPage();
      } else {
        nextPage = const ActivationWelcomePage();
      }
    }

    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient background layer
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return Opacity(
                opacity: _gradientOpacityAnimation.value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                ),
              );
            },
          ),

          // Logo layer
          Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: Image.asset(
                      'assets/images/logo_full.png',
                      width: 400,
                      height: 400,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
