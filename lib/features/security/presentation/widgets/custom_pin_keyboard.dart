import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CustomPinKeyboard extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool showBiometric;

  const CustomPinKeyboard({
    super.key,
    required this.onNumberPressed,
    required this.onBackspace,
    this.onBiometric,
    this.showBiometric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 12),
          _buildRow([
            showBiometric ? 'bio' : '',
            '0',
            'back',
          ]),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((num) => _buildKey(num)).toList(),
    );
  }

  Widget _buildKey(String value) {
    if (value.isEmpty) {
      return const SizedBox(width: 80, height: 80);
    }

    if (value == 'back') {
      return _buildIconKey(
        icon: Icons.backspace_outlined,
        onPressed: onBackspace,
      );
    }

    if (value == 'bio') {
      return _buildIconKey(
        icon: Icons.fingerprint,
        onPressed: onBiometric ?? () {},
        color: AppColors.primary,
      );
    }

    return _buildNumberKey(value);
  }

  Widget _buildNumberKey(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNumberPressed(number),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconKey({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 32,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
