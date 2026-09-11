import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/face_scan_icon.dart';

class FuturisticBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FuturisticBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84.5,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Custom painted background with notch
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 80),
            painter: _BottomNavPainter(isAbsensiActive: currentIndex == 1),
          ),

          // Navigation items
          Row(
            children: [
              // Beranda
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Beranda',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),

              // Jadwal
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today,
                  label: 'Jadwal',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              ),

              // Absensi (center) - larger size
              Expanded(
                child: _CenterAbsensiItem(
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),

              // Kinerja
              Expanded(
                child: _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Kinerja',
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),

              // Akun
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Akun',
                  isActive: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNavPainter extends CustomPainter {
  final bool isAbsensiActive;

  _BottomNavPainter({required this.isAbsensiActive});

  @override
  void paint(Canvas canvas, Size size) {
    // Background putih
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    // Radius untuk sudut kiri dan kanan atas
    const cornerRadius = 20.0;

    // Mulai dari kiri bawah
    path.moveTo(0, size.height);

    // Garis ke kiri atas dengan radius
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Garis ke posisi sebelum notch tengah
    path.lineTo(size.width * 0.36, 0);

    // Buat kurva turun untuk notch (setengah lingkaran KE ATAS)
    path.quadraticBezierTo(size.width * 0.40, 0, size.width * 0.43, -12);

    // Arc membentuk setengah lingkaran ke atas
    path.arcToPoint(
      Offset(size.width * 0.57, -12),
      radius: const Radius.circular(80),
      clockwise: false,
    );

    // Kurva kembali ke baseline
    path.quadraticBezierTo(size.width * 0.60, 0, size.width * 0.62, 0);

    // Garis ke kanan atas dengan radius
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Garis ke kanan bawah
    path.lineTo(size.width, size.height);

    // Close path
    path.close();

    canvas.drawPath(path, bgPaint);

    // Draw gradient overlay di area tengah untuk efek fokus
    if (isAbsensiActive) {
      final gradientRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.6,
        height: size.height * 2,
      );

      final gradient = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          AppColors.primary.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.0),
        ],
      );

      final gradientPaint = Paint()
        ..shader = gradient.createShader(gradientRect);

      canvas.drawPath(path, gradientPaint);
    }

    // Shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.1), 3, false);
  }

  @override
  bool shouldRepaint(_BottomNavPainter oldDelegate) {
    return oldDelegate.isAbsensiActive != isAbsensiActive;
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAbsensiItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CenterAbsensiItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient circle dengan icon - posisi di atas (lebih tinggi)
            // Gradient circle dengan icon - DINAIKKAN LEBIH TINGGI
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.emeraldGreen, AppColors.roseRed],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.face_retouching_natural,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Text(
                'Absensi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
