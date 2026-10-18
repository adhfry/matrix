import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/services/security_service.dart';
import 'setup_pin_page.dart';
import 'verify_pin_page.dart';
import 'debug_security_page.dart';

class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  SecurityService get _securityService => ref.read(securityServiceProvider);

  bool _isPinSet = false;
  bool _isBiometricEnabled = false;
  bool _canUseBiometric = false;
  String _biometricTypeName = 'Biometrik';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);

    final isPinSet = await _securityService.isPinSet();
    final isBiometricEnabled = await _securityService.isBiometricEnabled();
    final canUseBiometric = await _securityService.canUseBiometric();
    final biometricTypeName = await _securityService.getBiometricTypeName();

    setState(() {
      _isPinSet = isPinSet;
      _isBiometricEnabled = isBiometricEnabled;
      _canUseBiometric = canUseBiometric;
      _biometricTypeName = biometricTypeName;
      _isLoading = false;
    });
  }

  Future<void> _handleSetupPin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetupPinPage()),
    );

    if (result == true) {
      await _loadSecuritySettings();
    }
  }

  Future<void> _handleChangePin() async {
    // Verify current PIN first
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const VerifyPinPage(
          title: 'Verifikasi PIN Lama',
          description: 'Masukkan PIN lama Anda',
        ),
      ),
    );

    if (verified == true) {
      // Setup new PIN
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SetupPinPage()),
      );

      if (result == true) {
        if (!mounted) return;
        SnackBarHelper.showSuccess(context, 'PIN berhasil diubah');
        await _loadSecuritySettings();
      }
    }
  }

  Future<void> _handleRemovePin() async {
    // Verify PIN first
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const VerifyPinPage(
          title: 'Verifikasi PIN',
          description: 'Masukkan PIN untuk menghapus pengamanan',
        ),
      ),
    );

    if (verified == true) {
      // Confirm removal
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Hapus PIN?'),
          content: const Text(
            'Aplikasi tidak akan terkunci dengan PIN lagi. Anda yakin?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _securityService.removePin();
        if (!mounted) return;

        SnackBarHelper.showSuccess(context, 'PIN berhasil dihapus');
        await _loadSecuritySettings();
      }
    }
  }

  Future<void> _handleToggleBiometric(bool value) async {
    if (value) {
      print('=== Toggle Biometric ON ===');
      
      // Check if device supports biometric first
      final canUseBiometric = await _securityService.canUseBiometric();
      print('Can use biometric: $canUseBiometric');
      
      if (!canUseBiometric) {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          'Perangkat Anda tidak mendukung autentikasi biometrik',
        );
        return;
      }
      
      // Check available biometrics
      final biometrics = await _securityService.getAvailableBiometrics();
      print('Available biometrics: $biometrics');
      
      if (biometrics.isEmpty) {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          'Tidak ada biometrik yang terdaftar. Silakan daftarkan sidik jari atau face ID di pengaturan perangkat Anda',
        );
        return;
      }
      
      // Enable biometric - verify with biometric first
      try {
        print('Starting biometric authentication...');
        final authenticated = await _securityService.authenticateWithBiometric();
        print('Authentication result: $authenticated');
        
        if (!mounted) return;

        if (authenticated) {
          await _securityService.setBiometricEnabled(true);
          setState(() => _isBiometricEnabled = true);

          SnackBarHelper.showSuccess(
            context,
            '$_biometricTypeName berhasil diaktifkan',
          );
        } else {
          SnackBarHelper.showError(
            context,
            'Gagal memverifikasi $_biometricTypeName. Silakan coba lagi.',
          );
        }
      } catch (e) {
        print('=== Toggle Biometric Error ===');
        print('Error: $e');
        
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          'Terjadi kesalahan: ${e.toString()}',
        );
      }
    } else {
      // Disable biometric
      await _securityService.setBiometricEnabled(false);
      setState(() => _isBiometricEnabled = false);

      if (!mounted) return;
      SnackBarHelper.showInfo(
        context,
        '$_biometricTypeName dinonaktifkan',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Keamanan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Debug button
          IconButton(
            icon: const Icon(Icons.bug_report, color: AppColors.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DebugSecurityPage(),
                ),
              );
            },
            tooltip: 'Debug Security',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // PIN Section
                _buildSectionCard(
                  icon: Icons.lock_outline,
                  title: 'Kunci PIN',
                  subtitle: _isPinSet ? 'PIN sudah diatur' : 'Belum ada PIN',
                  gradient: AppColors.primaryGradient,
                  children: [
                    if (!_isPinSet)
                      _buildMenuItem(
                        icon: Icons.add_circle_outline,
                        title: 'Buat PIN',
                        subtitle: 'Buat PIN 6 digit untuk mengamankan aplikasi',
                        onTap: _handleSetupPin,
                      )
                    else ...[
                      _buildMenuItem(
                        icon: Icons.edit_outlined,
                        title: 'Ubah PIN',
                        subtitle: 'Ganti PIN Anda',
                        onTap: _handleChangePin,
                      ),
                      _buildMenuItem(
                        icon: Icons.delete_outline,
                        title: 'Hapus PIN',
                        subtitle: 'Nonaktifkan kunci PIN',
                        onTap: _handleRemovePin,
                        isDestructive: true,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Biometric Section
                _buildSectionCard(
                  icon: Icons.fingerprint,
                  title: 'Kunci $_biometricTypeName',
                  subtitle: _isBiometricEnabled
                      ? 'Aktif'
                      : _isPinSet
                      ? 'Nonaktif'
                      : 'Perlu PIN terlebih dahulu',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.info,
                      AppColors.info.withValues(alpha: 0.7),
                    ],
                  ),
                  children: [
                    _buildSwitchItem(
                      icon: _biometricTypeName == 'Face ID'
                          ? Icons.face
                          : Icons.fingerprint,
                      title: 'Aktifkan $_biometricTypeName',
                      subtitle: _isPinSet
                          ? 'Gunakan $_biometricTypeName untuk masuk aplikasi'
                          : 'Anda harus mengatur PIN terlebih dahulu',
                      value: _isBiometricEnabled,
                      onChanged: _isPinSet && _canUseBiometric
                          ? _handleToggleBiometric
                          : null,
                    ),

                    if (!_canUseBiometric)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Perangkat Anda tidak mendukung $_biometricTypeName',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Tentang Keamanan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• PIN digunakan untuk mengunci aplikasi\n'
                        '• $_biometricTypeName hanya bisa diaktifkan jika PIN sudah diatur\n'
                        '• Jangan bagikan PIN kepada siapa pun\n'
                        '• Hubungi administrator jika lupa PIN',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (isDestructive ? AppColors.error : AppColors.emeraldGreen)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.emeraldGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.emeraldGreen,
          ),
        ],
      ),
    );
  }
}



