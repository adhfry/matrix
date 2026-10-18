import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/security_service.dart';

class DebugSecurityPage extends ConsumerStatefulWidget {
  const DebugSecurityPage({super.key});

  @override
  ConsumerState<DebugSecurityPage> createState() => _DebugSecurityPageState();
}

class _DebugSecurityPageState extends ConsumerState<DebugSecurityPage> {
  SecurityService get _securityService => ref.read(securityServiceProvider);
  Map<String, String?> _allKeys = {};
  bool _isPinSet = false;
  bool _isBiometricEnabled = false;
  String _testPin = '123456';
  String _output = '';

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    final keys = await _securityService.debugGetAllKeys();
    final pinSet = await _securityService.isPinSet();
    final bioEnabled = await _securityService.isBiometricEnabled();

    setState(() {
      _allKeys = keys;
      _isPinSet = pinSet;
      _isBiometricEnabled = bioEnabled;
    });
  }

  Future<void> _testSetPin() async {
    setState(() => _output = 'Setting PIN: $_testPin...');
    
    await _securityService.setPin(_testPin);
    
    setState(() => _output = 'PIN set! Verifying...');
    await Future.delayed(const Duration(milliseconds: 500));
    
    final isValid = await _securityService.verifyPin(_testPin);
    final isPinSet = await _securityService.isPinSet();
    
    setState(() {
      _output = '''
✅ PIN Set Complete!

Verification: ${isValid ? 'PASS ✅' : 'FAIL ❌'}
isPinSet(): ${isPinSet ? 'true ✅' : 'false ❌'}

Reloading debug info...
''';
    });
    
    await _loadDebugInfo();
  }

  Future<void> _testVerifyPin() async {
    setState(() => _output = 'Verifying PIN: $_testPin...');
    
    final isValid = await _securityService.verifyPin(_testPin);
    
    setState(() {
      _output = '''
Verify Result: ${isValid ? 'VALID ✅' : 'INVALID ❌'}
''';
    });
  }

  Future<void> _clearAll() async {
    setState(() => _output = 'Clearing all data...');
    
    await _securityService.debugClearAll();
    
    setState(() => _output = 'All data cleared!');
    await _loadDebugInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Debug Security',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            _buildSection(
              'Status',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow('PIN Set', _isPinSet),
                  _buildStatusRow('Biometric Enabled', _isBiometricEnabled),
                  _buildStatusRow(
                    'Total Keys Stored',
                    _allKeys.isNotEmpty,
                    subtitle: '${_allKeys.length} keys',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stored Keys
            _buildSection(
              'Stored Keys',
              _allKeys.isEmpty
                  ? const Text('No keys stored')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _allKeys.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                entry.value?.substring(
                                      0,
                                      entry.value!.length > 50
                                          ? 50
                                          : entry.value!.length,
                                    ) ??
                                    'null',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 16),

            // Test PIN Input
            _buildSection(
              'Test PIN',
              TextField(
                controller: TextEditingController(text: _testPin),
                onChanged: (value) => _testPin = value,
                decoration: const InputDecoration(
                  labelText: 'PIN to test',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            _buildSection(
              'Actions',
              Column(
                children: [
                  _buildActionButton(
                    'Set PIN',
                    Icons.lock_outline,
                    _testSetPin,
                    AppColors.emeraldGreen,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    'Verify PIN',
                    Icons.check_circle_outline,
                    _testVerifyPin,
                    AppColors.info,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    'Reload Debug Info',
                    Icons.refresh,
                    _loadDebugInfo,
                    AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    'Clear All Data',
                    Icons.delete_forever,
                    _clearAll,
                    AppColors.error,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Output
            if (_output.isNotEmpty)
              _buildSection(
                'Output',
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _output,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
