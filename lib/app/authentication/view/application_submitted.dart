import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';

class ApplicationSubmittedView extends StatelessWidget {
  const ApplicationSubmittedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.text(
                'Welcome to Circum.',
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
              const SizedBox(height: 12),
              AppText.text(
                "Your rider application has been received. Our team will review your details and notify you once you're approved.",
                color: AppColors.textGrey,
                fontSize: 16,
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: AppColors.warning.withOpacity(0.4)),
                          ),
                          child: AppText.text(
                            'Pending Review',
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _timeline('Account Created', true),
                        _timeline('Phone Verified', true),
                        _timeline('Email Verified', true),
                        _timeline('Application Submitted', true),
                        _timeline('Under Review', false),
                        _timeline('Ready to Deliver', false),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton.button(
                backgroundColor: Colors.white.withOpacity(0.08),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
                onPressed: () => context.read<AuthBloc>().add(SignOut()),
                widget: AppText.text(
                  'Sign out',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeline(String label, bool complete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: complete ? AppColors.success : AppColors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          AppText.text(
            label,
            color: complete ? Colors.white : AppColors.textGrey,
            fontWeight: complete ? FontWeight.w800 : FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
