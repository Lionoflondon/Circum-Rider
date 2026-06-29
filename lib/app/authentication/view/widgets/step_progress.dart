import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../utils/theme/theme.dart';

class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.currentStep,
  });

  final int currentStep;

  static const _labels = ['Account', 'Phone', 'Email', 'Location'];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.text(
                'Step $currentStep of 4',
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(_labels.length, (index) {
                  final step = index + 1;
                  final isCurrent = step == currentStep;
                  final isDone = step < currentStep;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == _labels.length - 1 ? 0 : 8,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 52,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primary.withOpacity(0.18)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrent || isDone
                                ? AppColors.primary.withOpacity(0.65)
                                : Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.28),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isDone ? Icons.check_circle : Icons.circle,
                              color: isDone || isCurrent
                                  ? AppColors.primary
                                  : AppColors.grey,
                              size: 16,
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              child: AppText.text(
                                _labels[index],
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
