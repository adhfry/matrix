import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileDetailPage extends ConsumerWidget {
  const ProfileDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ref),
          SliverToBoxAdapter(
            child: userAsync.when(
              data: (user) => _buildContent(context, user),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text('Gagal memuat profil', style: AppTextStyles.h6),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: userAsync.when(
            data: (user) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                _buildProfilePhoto(user?.foto, user?.name),
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
                if (user?.nip != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'NIP: ${user!.nip}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(String? fotoUrl, String? name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.white,
        child: fotoUrl != null && fotoUrl.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: fotoUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint('Error loading image: $error');
                    debugPrint('Image URL: $url');
                    return _buildInitialAvatar(name);
                  },
                ),
              )
            : _buildInitialAvatar(name),
      ),
    );
  }

  Widget _buildInitialAvatar(String? name) {
    return Center(
      child: Text(
        name?.substring(0, 1).toUpperCase() ?? 'U',
        style: AppTextStyles.h2.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, user) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informasi Pribadi'),
          const SizedBox(height: 12),
          _buildInfoCard([
            _buildInfoRow(
              Icons.person_outline,
              'Nama Lengkap',
              user?.name ?? '-',
            ),
            _buildInfoRow(Icons.badge_outlined, 'NIP', user?.nip ?? '-'),
            _buildInfoRow(Icons.work_outline, 'Jabatan', user?.jabatan ?? '-'),
            _buildInfoRow(Icons.email_outlined, 'Email', user?.email ?? '-'),
            _buildInfoRow(
              Icons.account_circle_outlined,
              'Username',
              user?.username ?? '-',
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('Informasi Kehadiran'),
          const SizedBox(height: 12),
          _buildInfoCard([
            _buildInfoRow(
              Icons.access_time,
              'Mode Absensi',
              _getAttendanceMode(user?.attendanceMode),
            ),
            _buildInfoRow(
              Icons.category_outlined,
              'Kategori Pekerjaan',
              user?.jobCategory ?? '-',
            ),
            _buildInfoRow(
              Icons.verified_user_outlined,
              'Status ATLM',
              user?.statusAtlm ?? '-',
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18.0, 14.0, 0.0, 4.0),
      child: Text(
        title,
        style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAttendanceMode(String? mode) {
    switch (mode) {
      case 'Fixed':
        return 'Shift Tetap';
      case 'Flexi':
        return 'Shift Fleksibel';
      default:
        return mode ?? '-';
    }
  }
}
