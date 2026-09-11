import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/security_service.dart';
import '../../../attendance/presentation/pages/attendance_history_page.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/user_provider.dart';
import '../../../leave/presentation/pages/leave_request_page.dart';
import '../../../profile/presentation/pages/profile_detail_page.dart';
import '../../../security/presentation/pages/pin_setup_page.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: 24),
              _buildProfileCard(context, ref),
              const SizedBox(height: 16),
              _buildMenuSection(context, ref),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileDetailPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 38, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.accent],
          ),
        ),
        child: userAsync.when(
          data: (user) => Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: (user?.foto != null && user!.foto!.isNotEmpty)
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: user.foto!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint('Error loading image: $error');
                                  debugPrint('Image URL: $url');
                                  return Text(
                                    user.name.substring(0, 1).toUpperCase(),
                                    style: AppTextStyles.h3.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Text(
                              user?.name.substring(0, 1).toUpperCase() ?? 'U',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Nama Pengguna',
                style: AppTextStyles.h5.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                user?.jabatan ?? 'Jabatan',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'NIP: ${user?.nip ?? '-'}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          loading: () => Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat...',
                style: AppTextStyles.h5.copyWith(color: Colors.white),
              ),
            ],
          ),
          error: (error, _) => Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.error, color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat profil',
                style: AppTextStyles.h6.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: userAsync.when(
            data: (user) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informasi Profil',
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildProfileItem(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '-',
                ),
                const Divider(height: 24),
                _buildProfileItem(
                  icon: Icons.badge_outlined,
                  label: 'Username',
                  value: user?.username ?? '-',
                ),
                const Divider(height: 24),
                _buildProfileItem(
                  icon: Icons.medical_services_outlined,
                  label: 'Status ATLM',
                  value: user?.statusAtlm ?? '-',
                ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Gagal memuat data profil'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildMenuCard(
            title: 'Profil Saya',
            icon: Icons.person_outline,
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileDetailPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildMenuCard(
            title: 'Pengaturan PIN',
            icon: Icons.pin_outlined,
            color: AppColors.warning,
            onTap: () async {
              final security = ref.read(securityServiceProvider);
              final hasPIN = await security.isPinSet();

              if (hasPIN) {
                // Show options: Change PIN or Disable PIN
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pengaturan PIN'),
                    content: const Text(
                      'PIN sudah aktif. Apa yang ingin Anda lakukan?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          // Disable PIN
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Nonaktifkan PIN?'),
                              content: const Text(
                                'Anda harus login dengan username dan password setiap kali membuka aplikasi.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                  ),
                                  child: const Text('Nonaktifkan'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            await security.deletePin();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PIN berhasil dinonaktifkan'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: const Text('Nonaktifkan PIN'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Navigate to Change PIN page
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fitur ubah PIN akan segera hadir'),
                            ),
                          );
                        },
                        child: const Text('Ubah PIN'),
                      ),
                    ],
                  ),
                );
              } else {
                // Navigate to PIN Setup
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PinSetupPage(
                      onSuccess: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN berhasil diaktifkan'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          _buildMenuCard(
            title: 'Biometrik',
            icon: Icons.fingerprint,
            color: AppColors.info,
            onTap: () async {
              final security = ref.read(securityServiceProvider);
              final hasPIN = await security.isPinSet();

              if (!hasPIN) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Harap setup PIN terlebih dahulu'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              final isAvailable = await security.isBiometricAvailable();
              if (!isAvailable) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometrik tidak tersedia di perangkat ini'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final isEnabled = await security.isBiometricEnabled();

              if (!context.mounted) return;

              if (isEnabled) {
                // Disable biometric
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Nonaktifkan Biometrik?'),
                    content: const Text(
                      'Anda harus memasukkan PIN untuk membuka aplikasi.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Nonaktifkan'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await security.setBiometricEnabled(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Biometrik berhasil dinonaktifkan'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } else {
                // Enable biometric
                final success = await security.authenticateWithBiometric();

                if (success && context.mounted) {
                  await security.setBiometricEnabled(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Biometrik berhasil diaktifkan'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal mengaktifkan biometrik'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
          _buildMenuCard(
            title: 'Riwayat Absensi',
            icon: Icons.history_outlined,
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceHistoryPage()),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildMenuCard(
            title: 'Pengajuan Izin/Cuti',
            icon: Icons.event_note_outlined,
            color: AppColors.info,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaveRequestPage()),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildMenuCard(
            title: 'Tentang Aplikasi',
            icon: Icons.info_outline,
            color: AppColors.textSecondary,
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // icon color white
              onPressed: () {
                _showLogoutDialog(context, ref);
              },
              icon: const Icon(Icons.logout, color: AppColors.textWhite),
              label: const Text(
                'Keluar',
                style: TextStyle(color: AppColors.textWhite),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang MATRIX Mobile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/images/logo.png', width: 80, height: 80),
            const SizedBox(height: 16),
            const Text(
              'SiLAKES MATRIX',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Versi: ${AppConstants.appVersion}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '© 2026 Labkesda Sumenep',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Developed by IT UPTD Labkesda Sumenep',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement logout
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
