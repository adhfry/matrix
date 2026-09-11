import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PinDisplay extends StatelessWidget {
  final int pinLength;
  final int currentLength;
  final bool hasError;

  const PinDisplay({
    super.key,
    required this.pinLength,
    required this.currentLength,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pinLength,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < currentLength
                  ? (hasError ? AppColors.error : AppColors.emeraldGreen)
                  : Colors.transparent,
              border: Border.all(
                color: hasError
                    ? AppColors.error
                    : (index < currentLength
                        ? AppColors.emeraldGreen
                        : AppColors.border),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
