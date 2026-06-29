import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../utils/theme/theme.dart';
import 'step_progress.dart';

class RiderOnboardingShell extends StatelessWidget {
  const RiderOnboardingShell({
    super.key,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showStepProgress = true,
    this.showBackButton = false,
    this.onBack,
  });

  final int currentStep;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showStepProgress;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: Stack(
        children: [
          const _RiderOnboardingBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth >= 720 ? 32 : 20,
                    20,
                    constraints.maxWidth >= 720 ? 32 : 20,
                    28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, content) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 14),
                                child: content,
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (showBackButton)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: RiderIconButton(
                                    icon: Icons.arrow_back_rounded,
                                    onPressed:
                                        onBack ?? () => Navigator.pop(context),
                                  ),
                                ),
                              if (showBackButton) const SizedBox(height: 14),
                              if (showStepProgress) ...[
                                StepProgress(currentStep: currentStep),
                                const SizedBox(height: 24),
                              ],
                              Text(
                                title,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'OpenSans',
                                  fontSize: 34,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontFamily: 'OpenSans',
                                  fontSize: 15,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 24),
                              child,
                              if (footer != null) ...[
                                const SizedBox(height: 18),
                                footer!,
                              ],
                            ],
                          ),
                        ),
                      ),
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

class _RiderOnboardingBackground extends StatelessWidget {
  const _RiderOnboardingBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.78, -0.92),
            radius: 1.2,
            colors: [
              Color(0x663B82F6),
              Color(0x1A2D89D4),
              Color(0x0007090F),
            ],
            stops: [0, 0.38, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.92, 0.16),
              radius: 1.1,
              colors: [
                Color(0x332D89D4),
                Color(0x0D75E6FF),
                Color(0x0007090F),
              ],
              stops: [0, 0.46, 1],
            ),
            backgroundBlendMode: BlendMode.screen,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x220F172A),
                  Color(0xFF07090F),
                  Color(0xFF05060A),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RiderGlassCard extends StatelessWidget {
  const RiderGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.075),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.18),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.105),
                Colors.white.withOpacity(0.045),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class RiderGlassTextField extends StatelessWidget {
  const RiderGlassTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.text(label, color: Colors.white, fontWeight: FontWeight.w800),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
          decoration: riderInputDecoration(suffix: suffix),
        ),
      ],
    );
  }
}

InputDecoration riderInputDecoration({Widget? suffix}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
  );
  return InputDecoration(
    filled: true,
    fillColor: const Color(0xFF101722).withOpacity(0.84),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    labelStyle: const TextStyle(color: AppColors.textGrey),
    hintStyle: TextStyle(color: AppColors.textGrey.withOpacity(0.68)),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.9)),
    ),
  );
}

class RiderPrimaryButton extends StatelessWidget {
  const RiderPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.36),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  )
                ]
              : null,
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF235CA1)],
          ),
        ),
        child: TextButton(
          onPressed: enabled && !isLoading ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class RiderSecondaryButton extends StatelessWidget {
  const RiderSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? AppColors.primary : AppColors.textGrey,
        minimumSize: const Size.fromHeight(46),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'OpenSans',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RiderTrustChip extends StatelessWidget {
  const RiderTrustChip({
    super.key,
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
          ],
          AppText.text(
            label,
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}

class RiderIconButton extends StatelessWidget {
  const RiderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: IconButton(
          onPressed: onPressed,
          color: Colors.white,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.08),
            side: BorderSide(color: Colors.white.withOpacity(0.14)),
          ),
        ),
      ),
    );
  }
}
