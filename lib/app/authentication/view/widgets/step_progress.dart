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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.text(
            'Step $currentStep of 4',
            color: AppColors.textGrey,
            fontSize: 12,
            fontWeight: FontWeight.w800,
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
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary.withOpacity(0.20)
                          : isDone
                              ? AppColors.primary.withOpacity(0.11)
                              : Colors.white.withOpacity(0.035),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent || isDone
                            ? AppColors.primary.withOpacity(0.62)
                            : Colors.white.withOpacity(0.10),
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.34),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : Icons.circle_rounded,
                            key: ValueKey('$step-$isDone'),
                            color: isDone || isCurrent
                                ? AppColors.primary
                                : AppColors.grey,
                            size: isCurrent ? 17 : 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          child: AppText.text(
                            _labels[index],
                            color: isCurrent || isDone
                                ? Colors.white
                                : AppColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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
    );
  }
}
